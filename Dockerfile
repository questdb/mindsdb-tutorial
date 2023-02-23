FROM python:3.7

# cat /etc/os-release
# Debian GNU/Linux 11 (bullseye)
# TCP ports:
# - 9000:  QuestDB Web Console
# - 8812:  QuestDB pg-wire
# - 9009:  QuestDB ILP ingress line protocol
# - 47334: MindsDB WebConsole
# - 47335: MindsDB mysql API
# - 47336: MindsDB mongodb API

EXPOSE 8812/tcp
EXPOSE 9000/tcp
EXPOSE 9009/tcp
EXPOSE 47334/tcp
EXPOSE 47335/tcp
EXPOSE 47336/tcp

# Update system - Install JDK 17
RUN apt-get -y update
RUN apt-get -y dist-upgrade
RUN apt-get -y install software-properties-common build-essential syslog-ng \
    ca-certificates gnupg2 lsb-release iputils-ping procps git curl wget vim \
    unzip less tar gzip bzip2 openssl lshw libxml2 net-tools
RUN wget -O- https://apt.corretto.aws/corretto.key | gpg --dearmor | tee /etc/apt/trusted.gpg.d/winehq.gpg > /dev/null
RUN add-apt-repository 'deb https://apt.corretto.aws stable main'
RUN apt-get update
RUN apt-get install -y java-17-amazon-corretto-jdk=1:17.0.3.6-1
RUN apt-get clean
RUN rm -rf /var/lib/apt/lists/*

# Create new user 'quest' - user and workdir
RUN useradd -ms /bin/bash quest
USER quest
WORKDIR /home/quest
ENV QUESTDB_TAG=7.0.0
ENV PYTHONUNBUFFERED 1
ENV JAVA_HOME=/usr/lib/jvm/java-17-amazon-corretto
ENV PATH="${JAVA_HOME}/bin:/home/quest/.local/bin:${PATH}"
RUN echo "alias l='ls -l'" >> ~/.bashrc
RUN echo "alias ll='ls -la'" >> ~/.bashrc
RUN echo "alias rm='rm -i'" >> ~/.bashrc

# Install/Configure QuestDB
RUN echo tag_name ${QUESTDB_TAG}
RUN curl -L -o questdb.tar.gz "https://github.com/questdb/questdb/releases/download/${QUESTDB_TAG}/questdb-${QUESTDB_TAG}-no-jre-bin.tar.gz"
RUN tar xvfz questdb.tar.gz
RUN rm questdb.tar.gz
RUN mv "questdb-${QUESTDB_TAG}-no-jre-bin" questdb
RUN mkdir csv
RUN mkdir tmp
RUN mkdir backups
RUN mkdir questdb/db
RUN mkdir questdb/conf
RUN echo "config.validation.strict=true" > questdb/conf/server.conf
RUN echo "query.timeout.sec=120" >> questdb/conf/server.conf
RUN echo "cairo.sql.copy.root=/home/quest/csv" >> questdb/conf/server.conf
RUN echo "cairo.sql.copy.work.root=/home/quest/tmp" >> questdb/conf/server.conf
RUN echo "cairo.sql.backup.root=/home/quest/backups" >> questdb/conf/server.conf
RUN ulimit -S unlimited
RUN ulimit -H unlimited

# Install requirements for datascience environment
RUN echo 'numpy pandas matplotlib seaborn questdb mindsdb'  | sed 's/ /\n/g' > requirements.txt
RUN pip install --upgrade pip
RUN pip install -r requirements.txt
RUN pip install git+https://github.com/mindsdb/lightwood.git@staging --upgrade --no-cache-dir

# Configure MindsDB
RUN mkdir mindsdb
RUN mkdir mindsdb/storage
RUN echo '{' > conf.json
RUN echo '  "config_version":"1.4",' >> conf.json
RUN echo '  "storage_dir": "/home/quest/mindsdb/storage",' >> conf.json
RUN echo '  "log": {' >> conf.json
RUN echo '    "level": {' >> conf.json
RUN echo '      "console": "ERROR",' >> conf.json
RUN echo '      "file": "WARNING",' >> conf.json
RUN echo '      "db": "WARNING"' >> conf.json
RUN echo '    }' >> conf.json
RUN echo '  },' >> conf.json
RUN echo '  "debug": false,' >> conf.json
RUN echo '  "integrations": {},' >> conf.json
RUN echo '  "api": {' >> conf.json
RUN echo '    "http": {' >> conf.json
RUN echo '      "host": "0.0.0.0",' >> conf.json
RUN echo '      "port": "47334"' >> conf.json
RUN echo '    },' >> conf.json
RUN echo '    "mysql": {' >> conf.json
RUN echo '      "host": "0.0.0.0",' >> conf.json
RUN echo '      "password": "",' >> conf.json
RUN echo '      "port": "47335",' >> conf.json
RUN echo '      "user": "mindsdb",' >> conf.json
RUN echo '      "database": "mindsdb",' >> conf.json
RUN echo '      "ssl": true' >> conf.json
RUN echo '    },' >> conf.json
RUN echo '    "mongodb": {' >> conf.json
RUN echo '      "host": "0.0.0.0",' >> conf.json
RUN echo '      "port": "47336",' >> conf.json
RUN echo '      "database": "mindsdb"' >> conf.json
RUN echo '    }' >> conf.json
RUN echo '  }' >> conf.json
RUN echo '}' >> conf.json
RUN mv conf.json mindsdb/mindsdb_config.json

# Prepare run script
RUN echo "#!/bin/bash" > run.sh
RUN echo "/home/quest/questdb/questdb.sh start -d /home/quest/questdb" >> run.sh
RUN echo "python -m mindsdb --config=/home/quest/mindsdb/mindsdb_config.json --api=http,mysql,mongodb" >> run.sh
RUN chmod 700 run.sh

CMD ["/bin/bash", "-c", "/home/quest/run.sh"]
