
create schema school default charset utf8mb4;

create user dev identified by '123456';
grant all on school.* to dev@'%';
grant select on *.* to dev@'%';
