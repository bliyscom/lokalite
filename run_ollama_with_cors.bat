@echo off
echo Stopping any existing Ollama processes...
taskkill /f /im ollama* 2>nul
echo.
echo Setting OLLAMA_ORIGINS to '*'
set OLLAMA_ORIGINS=*
echo Starting Ollama with CORS allowed...
ollama serve
pause
