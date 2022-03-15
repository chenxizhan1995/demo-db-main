
container:=java-demo-db
docker?=podman

MYSQL_ROOT_PASSWORD:=root
MYSQL_PORT:=3308
server.create:
	$(docker) run --name $(container) -dit \
		-v $(container):/var/lib/mysql \
		-p $(MYSQL_PORT):3306 \
		-e MYSQL_ROOT_PASSWORD=$(MYSQL_ROOT_PASSWORD) \
		mysql:8.0

server.start server.stop server.logs server.rm: server.%:
	$(docker) $*  $(container)

school.connect:
	mysql --host localhost --port $(MYSQL_PORT) --user dev --password=123456 school
