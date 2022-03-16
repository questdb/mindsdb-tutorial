FROM docker.io/pytorch/pytorch:1.10.0-cuda11.3-cudnn8-runtime

ARG MINDSDB_VERSION

ENV PYTHONUNBUFFERED=1
EXPOSE 47334/tcp
EXPOSE 47335/tcp
EXPOSE 47336/tcp
EXPOSE 8000/tcp

RUN python -m pip install --prefer-binary --no-cache-dir --upgrade pip==22.0.4 && \
    pip install --prefer-binary --no-cache-dir wheel==0.37.1 && \
    pip install --prefer-binary --no-cache-dir mindsdb==$MINDSDB_VERSION && \
    pip install --prefer-binary --no-cache-dir mindsdb-datasources[postgresql]

CMD bash -c 'python -m mindsdb --config=/root/mindsdb_config.json --api=http,mysql,mongodb'
