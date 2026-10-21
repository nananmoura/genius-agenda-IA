#!/usr/bin/env bash
URL="${N8N_WEBHOOK_URL:-http://localhost:5678/webhook-test/whatsapp}"
DIR="$(cd "$(dirname "$0")" && pwd)"

send() {
  echo "-> $1"
  curl -s -o /dev/null -w "   HTTP %{http_code}\n" -X POST "$URL" \
    -H 'Content-Type: application/json' -d @"$DIR/$2"
}

send "1) mensagem nova" whatsapp_message.json
send "2) mesma mensagem (duplicada)" whatsapp_message.json
send "3) evento de status" whatsapp_status.json
