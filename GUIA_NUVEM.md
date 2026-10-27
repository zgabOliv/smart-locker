# Banco + API na nuvem e APK sem instalar nada

Tudo pelo navegador. Resultado: o app funciona de qualquer lugar, com seu PC desligado.

## 1. Conta no Azure
- Estudante: https://azure.microsoft.com/free/students (e-mail da escola, sem cartão).
- Ou conta gratuita normal (pede cartão só para verificação).

## 2. Banco de dados (Azure SQL — mesmo SQL Server, sem mudar o código)
1. Portal Azure > **Criar um recurso > Azure SQL > Banco de dados SQL (único)**.
2. Clique em **Aplicar oferta gratuita** (se aparecer). Banco: **TCC**.
3. Servidor novo: escolha **autenticação SQL**, crie um login (ex.: `adminlocker`) e uma senha forte. Anote.
4. Rede: marque **Permitir que serviços e recursos do Azure acessem este servidor = Sim**.
5. Depois de criado, em **Cadeias de conexão** copie o endereço do servidor (`xxxx.database.windows.net`).

## 3. API (App Service)
1. **Criar um recurso > Aplicativo Web**: Publicar = Código, Pilha = **.NET 8**, SO = Linux, plano **Gratuito F1**.
2. No Aplicativo Web > **Configurações > Variáveis de ambiente**, adicione:
   - `ConnectionStrings__Db` = `Server=tcp:SEUSERVIDOR.database.windows.net,1433;Database=TCC;User ID=adminlocker;Password=SUA_SENHA;Encrypt=True;TrustServerCertificate=False;Connect Timeout=60;`
   - `Jwt__Key` = uma frase longa aleatória (32+ caracteres)
   - `AdminSenhaInicial` = a senha que você quer para o `admin`
3. **Configurações > Configuração > Configurações gerais**: ative **Credenciais de publicação de autenticação básica SCM** e salve.
4. Na página inicial do app, clique em **Baixar perfil de publicação**. Anote a URL (`https://NOME.azurewebsites.net`).

## 4. GitHub (publica a API e gera o APK sozinho)
1. Crie conta e um repositório **privado** em github.com.
2. **Add file > Upload files** e arraste TODO o conteúdo desta pasta (inclusive `.github`). Commit.
3. No repositório: **Settings > Secrets and variables > Actions**:
   - aba **Secrets** > New: `AZURE_PUBLISH_PROFILE` = conteúdo inteiro do arquivo de perfil de publicação.
   - aba **Variables** > New: `AZURE_APP_NAME` = nome do Aplicativo Web; `API_URL` = `https://NOME.azurewebsites.net`
4. Aba **Actions**: rode **Publicar API no Azure** (Run workflow). Depois **Gerar APK**.
5. Quando o APK terminar, abra a execução e baixe **smart-locker-apk** (Artifacts). Dentro do zip está o `app-release.apk`. Passe para o celular e instale.

## 5. Testar
- Abra `https://NOME.azurewebsites.net/armarios` no navegador: deve dar erro 401 (API no ar).
- No app: `SP3000001` / `demo123` (aluno) e `admin` / a senha de `AdminSenhaInicial`.

## Atenção
- O plano gratuito "dorme" quando ninguém usa: o primeiro acesso do dia pode levar ~30 s.
- A API cria as tabelas, o admin e o usuário demo sozinha na primeira execução.
- O app do desktop e a placa do armário também precisam apontar para o banco na nuvem (host, banco, usuário e senha do passo 2) se forem usados.
- As datas agora ficam em UTC no banco e aparecem em horário local no app.
