@echo OFF
color 0a
Title ngrok����
Mode con cols=109 lines=30
:START
ECHO.
Echo ==================================================================================
ECHO.
Echo                                Ngrok�������
ECHO.
Echo                               ����: Eaglering
ECHO.
Echo ==================================================================================
Echo.
echo.
echo.
:TUNNEL
Echo ������Ҫ����������ǰ׺���硰test�� �����������Ĵ�͸����Ϊ����test.dns.fastapi.com.cn��
ECHO.
ECHO.
set /p clientid=   �����룺
echo.
Echo ���뱾����վ��ַ���硰80����127.0.0.1:80��
ECHO.
ECHO.
set /p clientaddr=   �����룺
echo.
ngrok -config=ngrok.cfg -subdomain=%clientid% %clientaddr%
PAUSE
goto TUNNEL