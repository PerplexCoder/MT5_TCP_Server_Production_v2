@echo off
echo ========================================
echo   MT5 TCP Server - Setup Automatico
echo ========================================
echo.

REM Verificar se Python esta instalado
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERRO] Python nao encontrado. Instale Python 3.7+ primeiro.
    pause
    exit /b 1
)

echo [OK] Python encontrado

REM Verificar dependencias Python
echo Verificando dependencias Python...
python -c "import asyncio, json, socket" >nul 2>&1
if %errorlevel% neq 0 (
    echo [AVISO] Algumas dependencias podem estar faltando
    echo Instalando dependencias basicas...
    pip install asyncio
) else (
    echo [OK] Dependencias Python OK
)

REM Verificar se MetaEditor existe
set METAEDITOR="D:\mt5_xp\MetaEditor64.exe"
if exist %METAEDITOR% (
    echo [OK] MetaEditor encontrado
    echo Compilando servidor MT5...
    %METAEDITOR% /compile:MT5_Server_TCP.mq5 /log
    if exist "MT5_Server_TCP.ex5" (
        echo [OK] Compilacao concluida com sucesso
    ) else (
        echo [AVISO] Arquivo .ex5 nao encontrado. Verifique erros de compilacao.
    )
) else (
    echo [AVISO] MetaEditor nao encontrado em %METAEDITOR%
    echo Compile manualmente o arquivo MT5_Server_TCP.mq5
)

REM Configurar regra de firewall
echo.
echo Configurando firewall para porta 5557...
netsh advfirewall firewall add rule name="MT5 TCP Server" dir=in action=allow protocol=TCP localport=5557 >nul 2>&1
if %errorlevel% equ 0 (
    echo [OK] Regra de firewall adicionada
) else (
    echo [AVISO] Nao foi possivel adicionar regra de firewall automaticamente
    echo Execute como administrador ou configure manualmente
)

REM Testar conectividade de rede
echo.
echo Testando disponibilidade da porta 5557...
netstat -an | find ":5557" >nul 2>&1
if %errorlevel% equ 0 (
    echo [AVISO] Porta 5557 ja esta em uso
) else (
    echo [OK] Porta 5557 disponivel
)

echo.
echo ========================================
echo           SETUP CONCLUIDO
echo ========================================
echo.
echo Proximos passos:
echo 1. Abra o MetaTrader 5
echo 2. Arraste MT5_Server_TCP.ex5 para um grafico
echo 3. Configure as permissoes (Tools ^> Options ^> Expert Advisors)
echo 4. Execute: python expanded_mt5_test_client.py
echo.
echo Consulte INSTALLATION.md para detalhes completos
echo.
pause