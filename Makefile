#
#     ___                  _   ____  ____
#    / _ \ _   _  ___  ___| |_|  _ \| __ )
#   | | | | | | |/ _ \/ __| __| | | |  _ \
#   | |_| | |_| |  __/\__ \ |_| |_| | |_) |
#    \__\_\\__,_|\___||___/\__|____/|____/
#
#  Copyright (c) 2014-2019 Appsicle
#  Copyright (c) 2019-2022 QuestDB
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#  http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
#

ifeq (, $(shell which curl))
$(error "Command curl not found in $(PATH)")
endif

MINDSDB_VERSION := $(shell curl --silent "https://public.api.mindsdb.com/installer/release/docker___success___None")


build-mindsdb-image:
	docker build -f Dockerfile --no-cache --build-arg MINDSDB_VERSION=$(MINDSDB_VERSION) -t mindsdb/mindsdb:questdb_tutorial .

compose-up:
	docker-compose -f docker-compose.yaml up -d

compose-down:
	docker-compose -f docker-compose.yaml down --remove-orphans

docker-prune:
	echo "y" | docker container prune
	echo "y" | docker volume prune
