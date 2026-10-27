-- Pode rodar de novo sem problema (só cria o que falta)
USE TCC;
IF COL_LENGTH('Usuarios','SenhaHash') IS NULL ALTER TABLE Usuarios ADD SenhaHash NVARCHAR(100) NULL;
IF COL_LENGTH('Usuarios','Perfil')    IS NULL ALTER TABLE Usuarios ADD Perfil NVARCHAR(10) NOT NULL DEFAULT 'aluno';
IF OBJECT_ID('Acessos') IS NULL
CREATE TABLE Acessos (
  Id INT IDENTITY PRIMARY KEY,
  DataHora DATETIME NOT NULL DEFAULT GETDATE(),
  Armario NVARCHAR(50) NULL, Prontuario NVARCHAR(50) NULL,
  Acao NVARCHAR(60) NOT NULL, StatusPorta NVARCHAR(30) NULL, Operador NVARCHAR(50) NULL);
