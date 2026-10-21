param(
  [string]$User = "genius",
  [string]$Db = "genius"
)

docker compose cp tests/test_lembretes.sql db:/tmp/test_lembretes.sql
docker compose exec db psql -U $User -d $Db -v ON_ERROR_STOP=1 -f /tmp/test_lembretes.sql

if ($LASTEXITCODE -ne 0) {
  Write-Host "TESTES FALHARAM"
  exit 1
}

Write-Host "TODOS OS TESTES PASSARAM"
