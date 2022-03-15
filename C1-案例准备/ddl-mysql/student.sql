-- 学生表
-- MySQL （8.0）数据库
-- 2022-03-11 chenxizhan new
drop table if exists student;

create table student(
    sid bigint primary key comment '学号，主键',
    name varchar(63) not null comment '姓名',
    birthday date not null comment '出生日期',
    enrollment_date date not null comment '入学日期',
    departure_date date comment '离校日期',

    crt_time datetime not null default now() comment '记录插入日期',
    upt_time datetime not null default now() on update now() comment '记录最新更新日期'
);
