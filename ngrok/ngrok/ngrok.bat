@echo OFF
color 0a
Title ngrok启动
Mode con cols=109 lines=30
:START
ECHO.
Echo ==================================================================================
ECHO.
Echo                                Ngrok启动面板
ECHO.
Echo                               作者: Eaglering
ECHO.
Echo ==================================================================================
Echo.
echo.
echo.
:TUNNEL
Echo 输入需要启动的域名前缀，如“test” ，即分配给你的穿透域名为：“test.dns.fastapi.com.cn”
ECHO.
ECHO.
set /p clientid=   请输入：
echo.
Echo 输入本地网站地址，如“80”或“127.0.0.1:80”
ECHO.
ECHO.
set /p clientaddr=   请输入：
echo.
ngrok -config=ngrok.cfg -subdomain=%clientid% %clientaddr%
PAUSE
goto TUNNEL