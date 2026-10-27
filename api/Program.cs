using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Dapper;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.Data.SqlClient;
using Microsoft.IdentityModel.Tokens;

var b = WebApplication.CreateBuilder(args);
var cs = b.Configuration.GetConnectionString("Db")!;
var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(b.Configuration["Jwt:Key"]!));
b.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme).AddJwtBearer(o =>
{
    o.MapInboundClaims = false;
    o.TokenValidationParameters = new TokenValidationParameters
    {
        IssuerSigningKey = key, ValidateIssuer = false, ValidateAudience = false,
        RoleClaimType = "role", NameClaimType = "prontuario"
    };
});
b.Services.AddAuthorization();
var app = b.Build();
app.UseAuthentication();
app.UseAuthorization();

SqlConnection Db() => new(cs);
static Task Log(SqlConnection c, string? armario, string? pront, string acao, string? status, string? op) =>
    c.ExecuteAsync(@"INSERT INTO Acessos (Armario, Prontuario, Acao, StatusPorta, Operador)
                     VALUES (@armario,@pront,@acao,@status,@op)", new { armario, pront, acao, status, op });

// Cria o banco e as tabelas básicas se ainda não existirem (útil ao rodar em outro computador).
try
{
    var sb = new SqlConnectionStringBuilder(cs);
    var nomeBanco = sb.InitialCatalog;
    sb.InitialCatalog = "master";
    using var mc = new SqlConnection(sb.ConnectionString);
    mc.Execute($"IF DB_ID(N'{nomeBanco}') IS NULL CREATE DATABASE [{nomeBanco}]");
}
catch (Exception e)
{
    Console.WriteLine("ATENÇÃO: não consegui criar/verificar o banco: " + e.Message);
}
using (var c = Db())
{
    c.Execute(@"IF OBJECT_ID('Armarios') IS NULL
                CREATE TABLE Armarios (
                    Id INT IDENTITY PRIMARY KEY,
                    Codigo NVARCHAR(50) NOT NULL UNIQUE,
                    StatusPorta NVARCHAR(30) NULL DEFAULT 'fechada',
                    NivelBateria INT NULL DEFAULT 100,
                    UltimoUso DATETIME NULL,
                    AlertaArrombamento BIT NOT NULL DEFAULT 0)");
    c.Execute(@"IF OBJECT_ID('Usuarios') IS NULL
                CREATE TABLE Usuarios (
                    Prontuario NVARCHAR(50) NOT NULL PRIMARY KEY,
                    Nome NVARCHAR(150) NOT NULL,
                    Curso NVARCHAR(100) NULL,
                    ArmarioId INT NULL REFERENCES Armarios(Id),
                    Status NVARCHAR(20) NOT NULL DEFAULT 'Ativo')");
}

// Cria o que falta no banco (colunas de login e tabela de acessos). Pode rodar várias vezes.
using (var c = Db())
{
    c.Execute("IF COL_LENGTH('Usuarios','SenhaHash') IS NULL ALTER TABLE Usuarios ADD SenhaHash NVARCHAR(100) NULL");
    c.Execute("IF COL_LENGTH('Usuarios','Perfil') IS NULL ALTER TABLE Usuarios ADD Perfil NVARCHAR(10) NOT NULL DEFAULT 'aluno'");
      c.Execute(@"IF OBJECT_ID('Acessos') IS NULL
                CREATE TABLE Acessos (Id INT IDENTITY PRIMARY KEY, DataHora DATETIME NOT NULL DEFAULT GETUTCDATE(),
                    Armario NVARCHAR(50) NULL, Prontuario NVARCHAR(50) NULL, Acao NVARCHAR(60) NOT NULL,
                    StatusPorta NVARCHAR(30) NULL, Operador NVARCHAR(50) NULL)");
}

// Redefine temporariamente a senha do admin
using (var c = Db())
{
    var hash = BCrypt.Net.BCrypt.HashPassword("123456");

    var existe = c.ExecuteScalar<int>(
        "SELECT COUNT(*) FROM Usuarios WHERE Prontuario = 'admin'");

    if (existe > 0)
    {
        c.Execute(@"UPDATE Usuarios
                    SET SenhaHash = @h, Status = 'Ativo', Perfil = 'admin'
                    WHERE Prontuario = 'admin'",
            new { h = hash });
    }
    else
    {
        c.Execute(@"INSERT INTO Usuarios
                    (Prontuario, Nome, Curso, ArmarioId, Status, Perfil, SenhaHash)
                    VALUES ('admin', 'Administrador', '', NULL, 'Ativo', 'admin', @h)",
            new { h = hash });
    }
}

// Usuário de demonstração: SP3000001 / demo123, dono do armário "armario_demo".
// A cada início da API ele é criado ou corrigido (senha, status e vínculo com o armário).
try
{
    using var c = Db();
    if (c.ExecuteScalar<int>("SELECT COUNT(*) FROM Armarios WHERE Codigo='armario_demo'") == 0)
        c.Execute(@"INSERT INTO Armarios (Codigo, StatusPorta, NivelBateria, UltimoUso, AlertaArrombamento)
                    VALUES ('armario_demo','fechada',100,GETUTCDATE(),0)");
    var hashDemo = BCrypt.Net.BCrypt.HashPassword("demo123");
    if (c.ExecuteScalar<int>("SELECT COUNT(*) FROM Usuarios WHERE Prontuario='SP3000001'") == 0)
        c.Execute(@"INSERT INTO Usuarios (Prontuario, Nome, Curso, ArmarioId, Status, Perfil, SenhaHash)
                    VALUES ('SP3000001','Aluno Demonstração','Informática',
                            (SELECT Id FROM Armarios WHERE Codigo='armario_demo'),'Ativo','aluno',@h)", new { h = hashDemo });
    else
        c.Execute(@"UPDATE Usuarios SET SenhaHash=@h, Status='Ativo', Perfil='aluno',
                           ArmarioId=(SELECT Id FROM Armarios WHERE Codigo='armario_demo')
                    WHERE Prontuario='SP3000001'", new { h = hashDemo });
    Console.WriteLine("Usuário demo pronto: SP3000001 / demo123 (armario_demo)");
}
catch (Exception e)
{
    Console.WriteLine("ATENÇÃO: não consegui criar o usuário demo: " + e.Message);
}

const string SelectArmarios = @"
SELECT a.Codigo AS Id,
       (SELECT TOP 1 u.Prontuario FROM Usuarios u WHERE u.ArmarioId = a.Id) AS Dono,
       ISNULL(a.NivelBateria,0) AS Bateria, CONVERT(varchar(23), a.UltimoUso, 126) + 'Z' AS UltimoAcesso,
       ISNULL(a.StatusPorta,'fechada') AS StatusPorta,
       ISNULL(a.AlertaArrombamento,0) AS Alerta
FROM Armarios a";

app.MapPost("/login", async (LoginReq r) =>
{
    using var c = Db();
    var u = await c.QueryFirstOrDefaultAsync<UserRow>(
        @"SELECT u.Prontuario, u.Nome, a.Codigo AS ArmarioId, u.Perfil, u.SenhaHash
          FROM Usuarios u LEFT JOIN Armarios a ON a.Id = u.ArmarioId
          WHERE u.Prontuario=@p AND ISNULL(u.Status,'Ativo') NOT IN ('Inativo','Bloqueado','Suspenso')", new { p = r.Prontuario });
    if (u?.SenhaHash == null || !BCrypt.Net.BCrypt.Verify(r.Senha, u.SenhaHash))
        return Results.Unauthorized();
    var arm = string.IsNullOrWhiteSpace(u.ArmarioId) ? "" : u.ArmarioId;
    var jwt = new JwtSecurityToken(
        claims: new[] { new Claim("prontuario", u.Prontuario), new Claim("role", u.Perfil), new Claim("armario", arm) },
        expires: DateTime.UtcNow.AddDays(7),
        signingCredentials: new SigningCredentials(key, SecurityAlgorithms.HmacSha256));
    return Results.Ok(new { token = new JwtSecurityTokenHandler().WriteToken(jwt), perfil = u.Perfil, nome = u.Nome, armario = arm });
});

// ── Armários ──
app.MapGet("/armarios", async () =>
{
    using var c = Db();
    return Results.Ok(await c.QueryAsync<Armario>(SelectArmarios + " ORDER BY a.Codigo"));
}).RequireAuthorization(p => p.RequireRole("admin"));

app.MapGet("/armarios/{id}", async (string id, ClaimsPrincipal me) =>
{
    if (!me.IsInRole("admin") && me.FindFirstValue("armario") != id) return Results.Forbid();
    using var c = Db();
    var a = await c.QueryFirstOrDefaultAsync<Armario>(SelectArmarios + " WHERE a.Codigo=@id", new { id });
    return a is null ? Results.NotFound() : Results.Ok(a);
}).RequireAuthorization();

app.MapPost("/armarios", async (CodigoReq r, ClaimsPrincipal me) =>
{
    if (string.IsNullOrWhiteSpace(r.Codigo)) return Results.BadRequest("Informe o código.");
    using var c = Db();
    if (await c.ExecuteScalarAsync<int>("SELECT COUNT(*) FROM Armarios WHERE Codigo=@c", new { c = r.Codigo }) > 0)
        return Results.Conflict("Já existe um armário com esse código.");
    await c.ExecuteAsync(@"INSERT INTO Armarios (Codigo, StatusPorta, NivelBateria, UltimoUso, AlertaArrombamento)
                           VALUES (@c,'fechada',100,GETUTCDATE(),0)", new { c = r.Codigo });
    await Log(c, r.Codigo, null, "Armário cadastrado", "fechada", me.FindFirstValue("prontuario"));
    return Results.NoContent();
}).RequireAuthorization(p => p.RequireRole("admin"));

app.MapDelete("/armarios/{id}", async (string id, ClaimsPrincipal me) =>
{
    using var c = Db();
    try
    {
        var n = await c.ExecuteAsync("DELETE FROM Armarios WHERE Codigo=@id", new { id });
        if (n == 0) return Results.NotFound();
    }
    catch (SqlException e) when (e.Number == 547)
    {
        return Results.Conflict("O armário está vinculado a um usuário.");
    }
    await Log(c, id, null, "Armário removido", null, me.FindFirstValue("prontuario"));
    return Results.NoContent();
}).RequireAuthorization(p => p.RequireRole("admin"));

app.MapPost("/armarios/{id}/abrir", async (string id, string? via, ClaimsPrincipal me) =>
{
    if (!me.IsInRole("admin") && me.FindFirstValue("armario") != id) return Results.Forbid();
    using var c = Db();
    await c.ExecuteAsync("UPDATE Armarios SET StatusPorta='abrir_agora' WHERE Codigo=@id", new { id });
    var admin = me.IsInRole("admin");
    await Log(c, id, admin ? null : me.FindFirstValue("prontuario"),
              admin ? "Abertura emergência" : via == "nfc" ? "Abertura por NFC" : "Abertura pelo app", "abrir_agora", me.FindFirstValue("prontuario"));
    return Results.NoContent();
}).RequireAuthorization();

app.MapPost("/armarios/{id}/resetar-alerta", async (string id, ClaimsPrincipal me) =>
{
    using var c = Db();
    await c.ExecuteAsync("UPDATE Armarios SET AlertaArrombamento=0 WHERE Codigo=@id", new { id });
    await Log(c, id, null, "Alerta resetado", null, me.FindFirstValue("prontuario"));
    return Results.NoContent();
}).RequireAuthorization(p => p.RequireRole("admin"));

// ── Usuários ──
app.MapGet("/usuarios", async () =>
{
    using var c = Db();
    return Results.Ok(await c.QueryAsync<Usuario>(
        @"SELECT u.Prontuario, u.Nome, u.Curso, a.Codigo AS Armario, u.Status
          FROM Usuarios u LEFT JOIN Armarios a ON a.Id = u.ArmarioId
          WHERE u.Perfil <> 'admin' ORDER BY u.Nome"));
}).RequireAuthorization(p => p.RequireRole("admin"));

app.MapPost("/usuarios", async (NovoUsuario r, ClaimsPrincipal me) =>
{
    if (string.IsNullOrWhiteSpace(r.Prontuario) || string.IsNullOrWhiteSpace(r.Nome) || string.IsNullOrWhiteSpace(r.Senha))
        return Results.BadRequest("Prontuário, nome e senha são obrigatórios.");
    using var c = Db();
    if (await c.ExecuteScalarAsync<int>("SELECT COUNT(*) FROM Usuarios WHERE Prontuario=@p", new { p = r.Prontuario }) > 0)
        return Results.Conflict("Esse prontuário já está cadastrado.");
    object? armId = null;
    if (!string.IsNullOrWhiteSpace(r.Armario))
    {
        armId = await c.ExecuteScalarAsync<object?>("SELECT Id FROM Armarios WHERE Codigo=@c", new { c = r.Armario });
        if (armId is null) return Results.BadRequest("Armário não encontrado.");
    }
    await c.ExecuteAsync(@"INSERT INTO Usuarios (Prontuario, Nome, Curso, ArmarioId, Status, Perfil, SenhaHash)
                           VALUES (@p,@n,@cu,@a,'Ativo','aluno',@h)",
        new { p = r.Prontuario, n = r.Nome, cu = r.Curso ?? "", a = armId, h = BCrypt.Net.BCrypt.HashPassword(r.Senha) });
    await Log(c, r.Armario, r.Prontuario, "Usuário cadastrado", null, me.FindFirstValue("prontuario"));
    return Results.NoContent();
}).RequireAuthorization(p => p.RequireRole("admin"));

app.MapPost("/usuarios/{prontuario}/senha", async (string prontuario, SenhaReq r) =>
{
    using var c = Db();
    var n = await c.ExecuteAsync("UPDATE Usuarios SET SenhaHash=@h WHERE Prontuario=@p",
        new { h = BCrypt.Net.BCrypt.HashPassword(r.Senha), p = prontuario });
    return n == 0 ? Results.NotFound() : Results.NoContent();
}).RequireAuthorization(p => p.RequireRole("admin"));

// ── Relatório de acessos ──
app.MapGet("/acessos", async () =>
{
    using var c = Db();
    return Results.Ok(await c.QueryAsync<Acesso>("SELECT TOP 300 Id, CONVERT(varchar(23), DataHora, 126) + 'Z' AS DataHora, Armario, Prontuario, Acao, StatusPorta, Operador FROM Acessos ORDER BY Id DESC"));
}).RequireAuthorization(p => p.RequireRole("admin"));

Console.WriteLine(
    "HASH ADMIN: " +
    BCrypt.Net.BCrypt.HashPassword("123456")
);
app.Run();

record LoginReq(string Prontuario, string Senha);
record SenhaReq(string Senha);
record CodigoReq(string Codigo);
record NovoUsuario(string Prontuario, string Nome, string? Curso, string? Armario, string Senha);
record UserRow(string Prontuario, string Nome, string? ArmarioId, string Perfil, string? SenhaHash);
record Armario(string Id, string? Dono, int Bateria, string? UltimoAcesso, string StatusPorta, bool Alerta);
record Usuario(string Prontuario, string Nome, string? Curso, string? Armario, string? Status);
record Acesso(int Id, string? DataHora, string? Armario, string? Prontuario, string Acao, string? StatusPorta, string? Operador);
