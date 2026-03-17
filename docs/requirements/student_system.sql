-- 学生成绩管理系统数据库创建脚本

-- 创建数据库
CREATE DATABASE IF NOT EXISTS student_score_management;

-- 使用数据库
USE student_score_management;

-- 创建学生表
CREATE TABLE IF NOT EXISTS student (
    student_id VARCHAR(20) PRIMARY KEY COMMENT '学号',
    name VARCHAR(50) NOT NULL COMMENT '姓名',
    gender VARCHAR(10) NOT NULL COMMENT '性别',
    birth_date DATE COMMENT '出生日期',
    class VARCHAR(50) COMMENT '班级',
    major VARCHAR(100) COMMENT '专业'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='学生表';

-- 创建课程表
CREATE TABLE IF NOT EXISTS course (
    course_id VARCHAR(20) PRIMARY KEY COMMENT '课程号',
    course_name VARCHAR(100) NOT NULL COMMENT '课程名',
    credit INT NOT NULL COMMENT '学分',
    semester VARCHAR(20) COMMENT '开课学期'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='课程表';

-- 创建成绩表
CREATE TABLE IF NOT EXISTS score (
    student_id VARCHAR(20) NOT NULL COMMENT '学号',
    course_id VARCHAR(20) NOT NULL COMMENT '课程号',
    score DECIMAL(5,2) COMMENT '分数',
    exam_date DATE COMMENT '考试日期',
    PRIMARY KEY (student_id, course_id),
    FOREIGN KEY (student_id) REFERENCES student(student_id) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (course_id) REFERENCES course(course_id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='成绩表';