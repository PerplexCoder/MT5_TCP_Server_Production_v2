@echo off
REM ============================================================================
REM MT5 TCP Server - Script de Configuração e Instalação
REM Versão: 2.00
REM Autor: PerplexCoder
REM Copyright: 2025, PerplexCoder
REM Data: Janeiro 2025
REM ============================================================================

setlocal EnableDelayedExpansion

REM Configurações
set PROJECT_NAME=MT5_TCP_Server_Production
set VERSION=2.00
set AUTHOR=PerplexCoder
set YEAR=2025

REM Cores para output
set RED=[91m
set GREEN=[92m
set YELLOW=[93m
set BLUE=[94m
set MAGENTA=[95m
set CYAN=[96m
set WHITE=[97m
set RESET=[0m

REM Diretórios
set CURRENT_DIR=%~dp0
set BACKUP_DIR=%CURRENT_DIR%backup
set LOGS_DIR=%CURRENT_DIR%logs
set MT5_EXPERTS_DIR=%APPDATA%\MetaQuotes\Terminal

echo %CYAN%============================================================================%RESET%
echo %CYAN%                    MT5 TCP Server - Setup Script v%VERSION%%RESET%
echo %CYAN%                         Autor: %AUTHOR% - %YEAR%%RESET%
echo %CYAN%============================================================================%RESET%
echo.

REM Verificar se está executando como administrador
net session >nul 2>&1
if %errorLevel% == 0 (
    echo %GREEN%[OK]%RESET% Executando com privilégios de administrador
) else (
    echo %YELLOW%[AVISO]%RESET% Recomenda-se executar como administrador para algumas operações
)

REM Menu principal
:MENU
echo.
echo %BLUE%Selecione uma opção:%RESET%
echo %WHITE%1.%RESET% Instalação completa
echo %WHITE%2.%RESET% Backup dos arquivos
echo %WHITE%3.%RESET% Restaurar backup
echo %WHITE%4.%RESET% Verificar instalação
echo %WHITE%5.%RESET% Configurar firewall
echo %WHITE%6.%RESET% Instalar dependências Python
echo %WHITE%7.%RESET% Compilar Expert Advisor
echo %WHITE%8.%RESET% Testar conectividade
echo %WHITE%9.%RESET% Limpar logs
echo %WHITE%0.%RESET% Sair
echo.
set /p choice=%CYAN%Digite sua escolha (0-9): %RESET%

if "%choice%"=="1" goto INSTALL_FULL
if "%choice%"=="2" goto BACKUP
if "%choice%"=="3" goto RESTORE
if "%choice%"=="4" goto VERIFY
if "%choice%"=="5" goto FIREWALL
if "%choice%"=="6" goto PYTHON_DEPS
if "%choice%"=="7" goto COMPILE_EA
if "%choice%"=="8" goto TEST_CONNECTIVITY
if "%choice%"=="9" goto CLEAN_LOGS
if "%choice%"=="0" goto EXIT

echo %RED%[ERRO]%RESET% Opção inválida!
goto MENU

:INSTALL_FULL
echo %YELLOW%[INFO]%RESET% Iniciando instalação completa...
call :CREATE_DIRS
call :BACKUP
call :PYTHON_DEPS
call :FIREWALL
call :COMPILE_EA
call :VERIFY
echo %GREEN%[SUCESSO]%RESET% Instalação completa finalizada!
goto MENU

:CREATE_DIRS
echo %YELLOW%[INFO]%RESET% Criando diretórios necessários...
if not exist "%BACKUP_DIR%" mkdir "%BACKUP_DIR%"
if not exist "%LOGS_DIR%" mkdir "%LOGS_DIR%"
echo %GREEN%[OK]%RESET% Diretórios criados
return

:BACKUP
echo %YELLOW%[INFO]%RESET% Criando backup dos arquivos...
set BACKUP_TIMESTAMP=%date:~-4,4%%date:~-10,2%%date:~-7,2%_%time:~0,2%%time:~3,2%%time:~6,2%
set BACKUP_TIMESTAMP=%BACKUP_TIMESTAMP: =0%
set BACKUP_FOLDER=%BACKUP_DIR%\backup_%BACKUP_TIMESTAMP%

if not exist "%BACKUP_FOLDER%" mkdir "%BACKUP_FOLDER%"

if exist "MT5_Server_TCP.mq5" (
    copy "MT5_Server_TCP.mq5" "%BACKUP_FOLDER%\" >nul
    echo %GREEN%[OK]%RESET% MT5_Server_TCP.mq5 copiado
)

if exist "MT5_Server_TCP_Functions.mqh" (
    copy "MT5_Server_TCP_Functions.mqh" "%BACKUP_FOLDER%\" >nul
    echo %GREEN%[OK]%RESET% MT5_Server_TCP_Functions.mqh copiado
)

if exist "expanded_mt5_test_client.py" (
    copy "expanded_mt5_test_client.py" "%BACKUP_FOLDER%\" >nul
    echo %GREEN%[OK]%RESET% expanded_mt5_test_client.py copiado
)

if exist "config.ini" (
    copy "config.ini" "%BACKUP_FOLDER%\" >nul
    echo %GREEN%[OK]%RESET% config.ini copiado
)

if exist "README.md" (
    copy "README.md" "%BACKUP_FOLDER%\" >nul
    echo %GREEN%[OK]%RESET% README.md copiado
)

echo %GREEN%[SUCESSO]%RESET% Backup criado em: %BACKUP_FOLDER%
return

:RESTORE
echo %YELLOW%[INFO]%RESET% Listando backups disponíveis...
dir /b "%BACKUP_DIR%" 2>nul
if %errorlevel% neq 0 (
    echo %RED%[ERRO]%RESET% Nenhum backup encontrado!
    goto MENU
)

set /p backup_name=%CYAN%Digite o nome da pasta de backup: %RESET%
set RESTORE_PATH=%BACKUP_DIR%\%backup_name%

if not exist "%RESTORE_PATH%" (
    echo %RED%[ERRO]%RESET% Backup não encontrado!
    goto MENU
)

echo %YELLOW%[INFO]%RESET% Restaurando arquivos de %backup_name%...
copy "%RESTORE_PATH%\*.*" "%CURRENT_DIR%" >nul
echo %GREEN%[SUCESSO]%RESET% Arquivos restaurados!
return

:VERIFY
echo %YELLOW%[INFO]%RESET% Verificando instalação...

REM Verificar arquivos principais
set FILES_OK=0
if exist "MT5_Server_TCP.mq5" (
    echo %GREEN%[OK]%RESET% MT5_Server_TCP.mq5 encontrado
    set /a FILES_OK+=1
) else (
    echo %RED%[ERRO]%RESET% MT5_Server_TCP.mq5 não encontrado
)

if exist "MT5_Server_TCP_Functions.mqh" (
    echo %GREEN%[OK]%RESET% MT5_Server_TCP_Functions.mqh encontrado
    set /a FILES_OK+=1
) else (
    echo %RED%[ERRO]%RESET% MT5_Server_TCP_Functions.mqh não encontrado
)

if exist "expanded_mt5_test_client.py" (
    echo %GREEN%[OK]%RESET% expanded_mt5_test_client.py encontrado
    set /a FILES_OK+=1
) else (
    echo %RED%[ERRO]%RESET% expanded_mt5_test_client.py não encontrado
)

if exist "config.ini" (
    echo %GREEN%[OK]%RESET% config.ini encontrado
    set /a FILES_OK+=1
) else (
    echo %RED%[ERRO]%RESET% config.ini não encontrado
)

REM Verificar Python
python --version >nul 2>&1
if %errorlevel% == 0 (
    echo %GREEN%[OK]%RESET% Python instalado
    set /a FILES_OK+=1
) else (
    echo %RED%[ERRO]%RESET% Python não encontrado
)

if %FILES_OK% geq 4 (
    echo %GREEN%[SUCESSO]%RESET% Instalação verificada com sucesso!
) else (
    echo %RED%[ERRO]%RESET% Problemas encontrados na instalação
)
return

:FIREWALL
echo %YELLOW%[INFO]%RESET% Configurando regras do firewall...

REM Verificar se está executando como admin
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo %RED%[ERRO]%RESET% É necessário executar como administrador para configurar o firewall
    goto MENU
)

REM Adicionar regra para porta 9090
netsh advfirewall firewall add rule name="MT5 TCP Server - Port 9090" dir=in action=allow protocol=TCP localport=9090 >nul 2>&1
if %errorlevel% == 0 (
    echo %GREEN%[OK]%RESET% Regra de firewall adicionada para porta 9090
) else (
    echo %YELLOW%[AVISO]%RESET% Regra de firewall pode já existir
)

REM Adicionar regra para Python
netsh advfirewall firewall add rule name="MT5 TCP Client - Python" dir=out action=allow program="python.exe" >nul 2>&1
if %errorlevel% == 0 (
    echo %GREEN%[OK]%RESET% Regra de firewall adicionada para Python
) else (
    echo %YELLOW%[AVISO]%RESET% Regra de firewall pode já existir
)

echo %GREEN%[SUCESSO]%RESET% Configuração do firewall concluída
return

:PYTHON_DEPS
echo %YELLOW%[INFO]%RESET% Instalando dependências Python...

REM Verificar se Python está instalado
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo %RED%[ERRO]%RESET% Python não está instalado ou não está no PATH
    echo %YELLOW%[INFO]%RESET% Baixe Python em: https://www.python.org/downloads/
    goto MENU
)

REM Instalar bibliotecas necessárias
echo %YELLOW%[INFO]%RESET% Instalando bibliotecas...
python -m pip install --upgrade pip >nul 2>&1

REM As bibliotecas socket, json, threading, datetime e logging são built-in
echo %GREEN%[OK]%RESET% Bibliotecas padrão já disponíveis (socket, json, threading, datetime, logging)

REM Instalar bibliotecas adicionais se necessário
echo %YELLOW%[INFO]%RESET% Verificando bibliotecas adicionais...
python -c "import requests" >nul 2>&1
if %errorlevel% neq 0 (
    echo %YELLOW%[INFO]%RESET% Instalando requests...
    python -m pip install requests >nul 2>&1
)

echo %GREEN%[SUCESSO]%RESET% Dependências Python verificadas/instaladas
return

:COMPILE_EA
echo %YELLOW%[INFO]%RESET% Compilando Expert Advisor...

REM Verificar se MetaEditor existe
set METAEDITOR_PATH=D:\mt5_xp\MetaEditor64.exe
if not exist "%METAEDITOR_PATH%" (
    echo %RED%[ERRO]%RESET% MetaEditor não encontrado em: %METAEDITOR_PATH%
    echo %YELLOW%[INFO]%RESET% Compile manualmente no MetaEditor
    goto MENU
)

REM Verificar se arquivo MQ5 existe
if not exist "MT5_Server_TCP.mq5" (
    echo %RED%[ERRO]%RESET% Arquivo MT5_Server_TCP.mq5 não encontrado
    goto MENU
)

echo %YELLOW%[INFO]%RESET% Abrindo MetaEditor para compilação...
echo %YELLOW%[INFO]%RESET% Compile o arquivo MT5_Server_TCP.mq5 manualmente (F7)
start "" "%METAEDITOR_PATH%" "%CURRENT_DIR%MT5_Server_TCP.mq5"

echo %GREEN%[INFO]%RESET% MetaEditor aberto. Compile manualmente e pressione qualquer tecla para continuar...
pause >nul
return

:TEST_CONNECTIVITY
echo %YELLOW%[INFO]%RESET% Testando conectividade...

REM Testar se a porta 9090 está aberta
netstat -an | findstr ":9090" >nul 2>&1
if %errorlevel% == 0 (
    echo %GREEN%[OK]%RESET% Porta 9090 está em uso (servidor pode estar rodando)
) else (
    echo %YELLOW%[AVISO]%RESET% Porta 9090 não está em uso
)

REM Testar conectividade básica
echo %YELLOW%[INFO]%RESET% Testando conectividade local...
ping -n 1 localhost >nul 2>&1
if %errorlevel% == 0 (
    echo %GREEN%[OK]%RESET% Conectividade local funcionando
) else (
    echo %RED%[ERRO]%RESET% Problema de conectividade local
)

REM Executar cliente de teste se disponível
if exist "expanded_mt5_test_client.py" (
    echo %YELLOW%[INFO]%RESET% Executando cliente de teste...
    echo %CYAN%Pressione Ctrl+C para interromper o teste%RESET%
    python expanded_mt5_test_client.py
) else (
    echo %YELLOW%[AVISO]%RESET% Cliente de teste não encontrado
)

return

:CLEAN_LOGS
echo %YELLOW%[INFO]%RESET% Limpando arquivos de log...

if exist "%LOGS_DIR%\*.log" (
    del /q "%LOGS_DIR%\*.log" >nul 2>&1
    echo %GREEN%[OK]%RESET% Logs do diretório logs/ removidos
) else (
    echo %YELLOW%[INFO]%RESET% Nenhum log encontrado no diretório logs/
)

if exist "*.log" (
    del /q "*.log" >nul 2>&1
    echo %GREEN%[OK]%RESET% Logs do diretório atual removidos
) else (
    echo %YELLOW%[INFO]%RESET% Nenhum log encontrado no diretório atual
)

echo %GREEN%[SUCESSO]%RESET% Limpeza de logs concluída
return

:EXIT
echo.
echo %CYAN%Obrigado por usar o MT5 TCP Server Setup!%RESET%
echo %CYAN%Autor: %AUTHOR% - %YEAR%%RESET%
echo.
pause
exit /b 0

REM ============================================================================
REM Funções auxiliares
REM ============================================================================

:LOG
set LOG_MSG=%~1
set LOG_FILE=%LOGS_DIR%\setup_%date:~-4,4%%date:~-10,2%%date:~-7,2%.log
echo [%time%] %LOG_MSG% >> "%LOG_FILE%"
return

:ERROR_HANDLER
echo %RED%[ERRO]%RESET% Ocorreu um erro durante a execução
echo %YELLOW%[INFO]%RESET% Verifique os logs para mais detalhes
pause
goto MENU

REM ============================================================================
REM Fim do script
REM ============================================================================