#!/bin/bash

# Configuração da webhook do Discord
DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/SEU_WEBHOOK_AQUI"

# Função para enviar mensagens para o Discord
discord_notify() {
    local message=$1
    curl -H "Content-Type: application/json" \
         -X POST \
         -d "{\"content\": \"$message\"}" $DISCORD_WEBHOOK_URL
}

DATETIME=`date +%y%m%d`
DATETIME_OLD=`date -d "15 days ago" +%y%m%d`
SRC=$1 #source 
DST=$2 #destination SPACE NAME
GIVENNAME=$3 #prefix name tar.gz
MYSQL_USER="_user"
MYSQL_PASSWORD="_password"
DATABASE_NAME="_db_name"

showhelp(){
    echo "\n\n############################################"
    echo "# bkupscript.sh                            #"
    echo "############################################"
    echo "\nEste script fará backup de arquivos/pastas em um único arquivo compactado e armazenará na pasta atual."
    echo "Para funcionar, este script precisa dos seguintes três parâmetros na ordem listada: "
    echo "\t- O caminho completo para a pasta ou arquivo que você deseja fazer backup."
    echo "\t- O nome do Space onde deseja armazenar o backup (apenas o nome, não a URL)."
    echo "\t- O nome para o arquivo de backup (o timestamp será adicionado ao início do nome do arquivo)\n"
    echo "Exemplo: sh bkupscript.sh ./testdir testSpace backupdata\n"
}

tarandzip(){
    echo "\n##### Coletando arquivos #####\n"
    if tar -czvf $GIVENNAME-$DATETIME.tar.gz $SRC; then
        echo "\n##### Arquivos coletados com sucesso #####\n"
        discord_notify "Backup criado com sucesso: $GIVENNAME-$DATETIME.tar.gz"
        return 0
    else
        echo "\n##### Falha ao coletar arquivos #####\n"
        discord_notify "Falha ao criar backup: $GIVENNAME-$DATETIME.tar.gz"
        return 1
    fi
}

movetoSpace(){
    echo "\n##### MOVENDO PARA O SPACE #####\n"
    if s3cmd put $GIVENNAME-$DATETIME.tar.gz s3://$DST; then
        echo "\n##### Arquivos enviados com sucesso para s3://$DST #####\n"
        discord_notify "Backup enviado com sucesso para s3://$DST"
        rm -rf ~/$GIVENNAME-$DATETIME.tar.gz
        return 0
    else
        echo "\n##### Falha ao enviar arquivos para o Space #####\n"
        discord_notify "Falha ao enviar backup para s3://$DST"
        return 1
    fi
}

dumpDatabases(){
    echo "\n##### EXPORTANDO TODOS OS BANCOS DE DADOS #####\n"
    mysqldump -u $MYSQL_USER -p$MYSQL_PASSWORD $DATABASE_NAME > $DATABASE_NAME-$GIVENNAME-$DATETIME.sql
    discord_notify "Banco de dados exportado: $DATABASE_NAME-$GIVENNAME-$DATETIME.sql"
    return 0
}

movetoSpaceDB(){
    echo "\n##### MOVENDO BANCO DE DADOS PARA O SPACE #####\n"
    if s3cmd put $DATABASE_NAME-$GIVENNAME-$DATETIME.sql s3://$DST; then
        echo "\n##### Banco de dados enviado com sucesso para s3://$DST #####\n"
        discord_notify "Banco de dados enviado com sucesso para s3://$DST"
        rm -rf ~/$DATABASE_NAME-$GIVENNAME-$DATETIME.sql
        return 0
    else
        echo "\n##### Falha ao enviar banco de dados para o Space #####\n"
        discord_notify "Falha ao enviar banco de dados para s3://$DST"
        return 1
    fi
}

removeOldBackupDB(){
    echo "\n##### REMOVENDO BACKUP ANTIGO DO BANCO DE DADOS #####\n"
    if s3cmd rm s3://$DST$DATABASE_NAME-$GIVENNAME-$DATETIME_OLD.sql; then
        echo "\n##### Backup antigo do banco de dados removido de s3://$DST #####\n"
        discord_notify "Backup antigo do banco de dados removido de s3://$DST"
        return 0
    else
        echo "\n##### Falha ao remover backup antigo do banco de dados #####\n"
        discord_notify "Falha ao remover backup antigo do banco de dados em s3://$DST"
        return 1
    fi
}

removeOldBackupFile(){
    echo "\n##### REMOVENDO BACKUP ANTIGO #####\n"
    if s3cmd rm s3://$DST$GIVENNAME-$DATETIME_OLD.tar.gz; then
        echo "\n##### Backup antigo removido de s3://$DST #####\n"
        discord_notify "Backup antigo removido de s3://$DST"
        return 0
    else
        echo "\n##### Falha ao remover backup antigo #####\n"
        discord_notify "Falha ao remover backup antigo de s3://$DST"
        return 1
    fi
}

if [ ! -z "$GIVENNAME" ]; then
    if tarandzip; then
        movetoSpace
        if dumpDatabases; then
            movetoSpaceDB
        fi
        removeOldBackupDB
        removeOldBackupFile
        discord_notify "Processo de backup concluído com sucesso."
    else
        showhelp
        discord_notify "Processo de backup falhou."
    fi
else
    showhelp
    discord_notify "Execução falhou: Parâmetros insuficientes."
fi
