
ARG MINDSDB_VERSION

FROM docker.io/mindsdb/mindsdb:$MINDSDB_VERSION


ENV PYTHONUNBUFFERED=1
EXPOSE 47334/tcp
EXPOSE 47335/tcp
EXPOSE 47336/tcp
EXPOSE 8000/tcp

RUN python -m pip install --prefer-binary --no-cache-dir --upgrade pip>=22.0.4 && \
    pip install --prefer-binary --no-cache-dir mindsdb-datasources[postgresql]

CMD bash -c 'python -m mindsdb --config=/root/mindsdb_config.json --api=http,mysql,mongodb'
