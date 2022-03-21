# jdbc 学习笔记
2022-03-11
## 纲领
要学的：
- jdbc 执行 DML 的方式，设置参数的方式，读取查询结果集的方式
- jdbc 中提供的数据类型，Java 类型、JDBC 类型、数据库类型之间的映射规则
- jdbc 调用存储过程，有时会涉及取得结果集
- jdbc 执行DDL语句
- jdbc 事务
- jdbc 连接池的朴素原理

不要学的
- 多表关联查询，复杂查询逻辑。这些更多是 SQL 或者数据库课程的内容，且学jdbc只是打基础，实战中基本不会用它的

next：jdbc 原理之：数据类型
## 快速入门
用 Java jdbc 连接数据库，执行查询语句，并输出查询结果。
假设已经有了一个 MySQL:8.0 的数据库服务（参考C1-案例准备/）。
假设使用 Maven 创建项目。

### 1. 引入 jdbc 驱动依赖（mysql）
mysql 驱动，坐标 mysql:mysql-connector-java:8.x

TODO: 版本对关系，好像 5.6 之前的，得用旧版驱动。之后的，都可以用 mysql:mysql-connenctor-java:8.x

坐标如下：
```xml
<dependency>
  <groupId>mysql</groupId>
  <artifactId>mysql-connector-java</artifactId>
  <version>[8, 9)</version>
  <scope>runtime</scope>
</dependency>
```

注意到这里添加依赖的scope是runtime。
因为编译Java程序并不需要MySQL的这个jar包，只有在运行期才需要使用。把runtime改成compile 也能正常编译，
但是在IDE里写程序的时候会多出来一大堆类似com.mysql.jdbc.Connection这样的类，
非常容易与Java标准库的JDBC接口混淆，所以没有设置为compile。
### 2. 示例代码: 获取/关闭连接

使用 jdbc，步骤如下
1. 注册驱动
2. 获取连接
3. 执行语句
4. 获取结果
5. 关闭连接

注册驱动，要知道驱动类的全限定名，mysql 驱动类的名称为 `com.mysql.cj.jdbc.Driver`。
PS：其中，cj 或许是 connector-java 的缩写。
PS: 这是 8.x 版本驱动的类名称，5.x 的，则是 com.mysql.jdbc.Driver。

获取连接时，要指定数据库服务地址（url），MYSQL 驱动的url格式为
```
jdbc:mysql://<hostname>:<port>/<db>?key1=value1&key2=value2
```

```java
public void getConnection2() {
    String JDBC_URL = "jdbc:mysql://localhost:3308/school?useSSL=false&characterEncoding=utf8&allowPublicKeyRetrieval=true";
    String JDBC_USER = "dev";
    String JDBC_PASSWORD = "123456";
    try {
        Class.forName("com.mysql.cj.jdbc.Driver");
        Connection con = DriverManager.getConnection(JDBC_URL, JDBC_USER, JDBC_PASSWORD);
        System.out.println("连接数据库成功");
    } catch (SQLException | ClassNotFoundException e) {
        System.out.println("连接数据库失败");
        e.printStackTrace();
    }
}
```
### 3. 示例代码：执行查询并返回结果

```java
public boolean query(){
    // 1. 载入数据库驱动
    try {
        Class.forName("com.mysql.cj.jdbc.Driver");
    } catch (ClassNotFoundException e){
        e.printStackTrace();
        return false;
    }
    // 2. 连接数据库
    String url = "jdbc:mysql://localhost:3308/school?useSSL=false&characterEncoding=utf8&allowPublicKeyRetrieval=true";
    String user = "dev";
    String password = "123456";
    try (Connection con = DriverManager.getConnection(url, user, password)){
        try (Statement st = con.createStatement()){
            try (ResultSet rs = st.executeQuery("select sid, name, birthday from school.student")){
                while (rs.next()){
                    // 注意，索引从 1 开始
                    Long sid = rs.getLong(1);
                    String sname = rs.getString(2);
                    Date birthday = rs.getDate(3);
                    System.out.println(String.format("%d, %s, %s", sid, sname, birthday));
                }
            }
        }
    } catch (SQLException e){
        e.printStackTrace();
        return false;
    }
    return true;
}
```

- Statment和ResultSet都是需要关闭的资源，因此嵌套使用try (resource)确保及时关闭；
- rs.next()用于判断是否有下一行记录，如果有，将自动把当前行移动到下一行（一开始获得ResultSet时当前行不是第一行）；
- ResultSet获取列时，索引从1开始而不是0；
- 必须根据SELECT的列的对应位置来调用getLong(1)，getString(2)这些方法，否则对应位置的数据类型不对，将报错。

使用 Stetement 拼接 SQL 语句存在SQL注入的风险。
```java
User login(String name, String pass) {
    ...
    stmt.executeQuery("SELECT * FROM user WHERE login='" + name + "' AND pass='" + pass + "'");
    ...
}
```
其中，参数name和pass通常都是Web页面输入后由程序接收到的。

如果攻击者传入恶意构造的字符串 "bob' OR pass=", pass = " OR pass='"，拼接出来的sql就会变成
```sql
SELECT * FROM user WHERE login='bob' OR pass=' AND pass=' OR pass=''
```
执行这条SQL，登录验证就形同虚设。

要避免SQL注入攻击，一个办法是针对所有字符串参数进行转义，但是转义很麻烦，而且需要在任何使用SQL的地方增加转义代码。

### 4. 示例代码：使用预编译语句执行查询并返回结果

要避免SQL注入攻击，一个办法是针对所有字符串参数进行转义，但是转义很麻烦，而且需要在任何使用SQL的地方增加转义代码。

还有一个办法就是使用PreparedStatement。使用PreparedStatement可以完全避免SQL注入的问题，因为PreparedStatement始终使用?作为占位符，并且把数据连同SQL本身传给数据库，这样可以保证每次传给数据库的SQL语句是相同的，只是占位符的数据不同，还能高效利用数据库本身对查询的缓存。
```java
public void query2(){
    // 1. 载入数据库驱动
      try {
          Class.forName("com.mysql.cj.jdbc.Driver");
      } catch (ClassNotFoundException e){
          e.printStackTrace();
      }
      // 2. 连接数据库
      String url = "jdbc:mysql://localhost:3308/school?useSSL=false&characterEncoding=utf8&allowPublicKeyRetrieval=true";
      String user = "dev";
      String password = "123456";
      try (Connection con = DriverManager.getConnection(url, user, password)){
          try (PreparedStatement st = con.prepareStatement("select sid, name ,birthday from student where name = ?")){
              st.setString(1, "Jack"); // 索引从 1 开始
              try (ResultSet rs = st.executeQuery()){
                  while (rs.next()){
                      // 注意，索引从 1 开始
                      Long sid = rs.getLong("sid");
                      String sname = rs.getString("name");
                      Date birthday = rs.getDate("birthday");
                      System.out.println(String.format("%d, %s, %s", sid, sname, birthday));
                  }
              }
          }
      } catch (SQLException e){
          e.printStackTrace();
      }
}
```
使用PreparedStatement和Statement稍有不同，必须首先调用setObject()设置每个占位符?的值，最后获取的仍然是ResultSet对象。

另外注意到从结果集读取列时，使用String类型的列名比索引要易读，而且不易出错。
## 理论知识
### SQL类型
- 类 JDBCType       Defines the constants that are used to identify generic SQL types, called JDBC types.
- 接口 SQLType
- Types             The class that defines the constants that are used to identify generic SQL types, called JDBC types.

```java
public enum JDBCType extends Enum<JDBCType> implements SQLType

public class Types  extends Object
```
这两个类是 JDBC 4.2 新增的内容。旧版以及现在的 jdbc 规范，对数据类型的
> Standard mappings for SQL types to classes and interfaces in the Java programming language
- Array interface -- mapping for SQL ARRAY
- Blob interface -- mapping for SQL BLOB
- Clob interface -- mapping for SQL CLOB
- Date class -- mapping for SQL DATE
- NClob interface -- mapping for SQL NCLOB
- Ref interface -- mapping for SQL REF
- RowId interface -- mapping for SQL ROWID
- Struct interface -- mapping for SQL STRUCT
- SQLXML interface -- mapping for SQL XML
- Time class -- mapping for SQL TIME
- Timestamp class -- mapping for SQL TIMESTAMP
- Types class -- provides constants for SQL types

## 附：参考资料
Java 官网教材，针对JDK8，英文的。
[Trail: JDBC Database Access (The Java™ Tutorials)](https://docs.oracle.com/javase/tutorial/jdbc/index.html)

JDBC API 文档
[Overview (Java Platform SE 8 )](https://docs.oracle.com/javase/8/docs/api/index.html?java/sql/package-summary.html)

廖雪峰老师的Java教程，初次接触，看这个就行。
[JDBC查询 - 廖雪峰的官方网站](https://www.liaoxuefeng.com/wiki/1252599548343744/1321748435828770)
## 附：可深入事项
- 加载驱动的原理以及所有可行方式，当前只会 Class.forName()
- 使用了 allowPublicKeyRetrieval=true 选项，但这样不安全
  [MySQL 8.0 Public Key Retrieval is not allowed 错误的解决方法_啦啦啦啦 la-CSDN博客](https://blog.csdn.net/u013360850/article/details/80373604)
  > com.mysql.jdbc.exceptions.jdbc4.MySQLNonTransientConnectionException: Public Key Retrieval is not allowed

## 附：JDBCType 一览表
Java 定义了枚举类 JDBCType，一共39个枚举值。
在线文档在这里 [JDBCType (Java SE 8)](https://docs.oracle.com/javase/8/docs/api/)

在线文档中是按枚举值的字母序列出的，这里按枚举值定义的顺序列出，相似的类型聚集在一起，方便查看。
```
0 , BIT         , java.sql
1 , TINYINT     , java.sql
2 , SMALLINT    , java.sql
3 , INTEGER     , java.sql
4 , BIGINT      , java.sql
5 , FLOAT       , java.sql
6 , REAL        , java.sql
7 , DOUBLE      , java.sql
8 , NUMERIC     , java.sql
9 , DECIMAL     , java.sql
10, CHAR        , java.sql
11, VARCHAR     , java.sql
12, LONGVARCHAR , java.sql
13, DATE        , java.sql
14, TIME        , java.sql
15, TIMESTAMP   , java.sql
16, BINARY      , java.sql
17, VARBINARY   , java.sql
18, LONGVARBINARY, java.sql
19, NULL        , java.sql
20, OTHER       , java.sql
21, JAVA_OBJECT , java.sql
22, DISTINCT    , java.sql
23, STRUCT      , java.sql
24, ARRAY       , java.sql
25, BLOB        , java.sql
26, CLOB        , java.sql
27, REF         , java.sql
28, DATALINK    , java.sql
29, BOOLEAN     , java.sql
30, ROWID       , java.sql
31, NCHAR       , java.sql
32, NVARCHAR    , java.sql
33, LONGNVARCHAR, java.sql
34, NCLOB       , java.sql
35, SQLXML      , java.sql
36, REF_CURSOR  , java.sql
37, TIME_WITH_TIMEZONE, java.sql
38, TIMESTAMP_WITH_TIMEZONE, java.sql
```
