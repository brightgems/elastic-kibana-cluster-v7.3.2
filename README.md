# 容器编排安装elastic集群

## 环境准备

创建安装目录并修改权限

```
#创建数据/日志目录 这里我们部署3个节点
mkdir /dvolumes/elasticsearch/data/{node0,node1,node2} -p
mkdir /dvolumes/elasticsearch/logs/{node0,node1,node2} -p
cd /dvolumes/elasticsearch
#权限我也很懵逼啦 给了 privileged 也不行 索性0777好了
chmod 0777 data/* -R && chmod 0777 logs/* -R

#防止JVM报错
echo vm.max_map_count=262144 >> /etc/sysctl.conf
sysctl -p
```
手工复制docker-compose.yml文件到目标机器安装目录

## 启动Elastic Search容器和Kibana容器
```
docker-compose up -d

docker-compose logs -tail 30
```

    *kibana配置文件的一个坑： 环境变量需要使用ELASTICSEARCH_HOSTS，ELASTICSEARCH_URL在新版本失效了 *

## 安装IK中文分词插件

```
wget https://github.com/medcl/elasticsearch-analysis-ik/releases/download/v7.3.2/elasticsearch-analysis-ik-7.3.2.zip
tar -xzf  elasticsearch-analysis-ik-7.3.2.zip
docker cp ik 31595b6a67bd:/usr/share/elasticsearch/plugins
```

IK提供两种分语方式
- ik_max_word:
- ik_smart: 

## 扩展IK词库
可以配置IKAnalyzer.cfg.xml 加入行业相关的词包

目录在：elasticsearch-5.4.0/plugins/ik/config

```
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE properties SYSTEM "http://java.sun.com/dtd/properties.dtd">
<properties>
    <comment>IK Analyzer 扩展配置</comment>
    <!--用户可以在这里配置自己的扩展字典 -->
    <entry key="ext_dict">custom/mydict.dic;custom/single_word_low_freq.dic</entry>
    <!--用户可以在这里配置自己的扩展停止词字典-->
    <entry key="ext_stopwords">custom/ext_stopword.dic</entry>
    <!--用户可以在这里配置远程扩展字典，下面是配置在nginx路径下面的 -->
    <entry key="remote_ext_dict">http://tagtic-slave01:82/HotWords.php</entry>
    <!--用户可以在这里配置远程扩展停止词字典-->
    <!-- <entry key="remote_ext_stopwords">words_location</entry> -->
    <entry key="remote_ext_stopwords">http://tagtic-slave01:82/StopWords.php</entry>
</properties>
```
`ref:` https://www.cnblogs.com/leixingzhi7/p/6903938.html

## 修改默认密码
Elastic Docker Images的默认账号密码是elastic/changeme，使用默认密码是不安全的，假设要把密码改为elastic0。在Docker所在服务器上执行命令，修改用户elastic的密码：
```
curl -XPUT -u elastic 'localhost:9200/_xpack/security/user/elastic/_password' -H "Content-Type: application/json" \
-d '{
  "password" : "elastic0"
}'
```

设置密码，重启Kibana：
```
docker stop my-kibana && docker rm my-kibana
docker run -p 5601:5601 -e "ELASTICSEARCH_URL=http://localhost:9200" -e "ELASTICSEARCH_PASSWORD=elastic0"  \
--name my-kibana --network host -d docker.elastic.co/kibana/kibana:5.5.1
```

## Elastic EQL 查询技巧

### 多数字段(Most Fields)
全文搜索是一场召回率(Recall) - 返回所有相关的文档，以及准确率(Precision) - 不返回无关文档，之间的战斗。目标是在结果的第一页给用户呈现最相关的文档。

为了提高召回率，我们会广撒网 - 不仅包括精确匹配了用户搜索词条的文档，还包括了那些我们认为和查询相关的文档。如果一个用户搜索了"quick brown fox"，一份含有fast foxes的文档也可以作为一个合理的返回结果。

如果我们拥有的相关文档仅仅是含有fast foxes的文档，那么它会出现在结果列表的顶部。但是如果我们有100份含有quick brown fox的文档，那么含有fast foxes的文档的相关性就会变低，我们希望它出现在结果列表的后面。在包含了许多可能的匹配后，我们需要确保相关度高的文档出现在顶部。

一个用来调优全文搜索相关性的常用技术是将同样的文本以多种方式索引，每一种索引方式都提供了不同相关度的信号(Signal)。主要字段(Main field)中含有的词条的形式是最宽泛的(Broadest-matching)，用来尽可能多的匹配文档。比如，我们可以这样做：

- 使用一个词干提取器来将jumps，jumping和jumped索引成它们的词根：jump。然后当用户搜索的是jumped时，我们仍然能够匹配含有jumping的文档。
- 包含同义词，比如jump，leap和hop。
- 移除变音符号或者声调符号：比如，ésta，está和esta都会以esta被索引。

但是，如果我们有两份文档，其中之一含有jumped，而另一份含有jumping，那么用户会希望第一份文档的排序会靠前，因为它含有用户输入的精确值。

我们可以通过将相同的文本索引到其它字段来提供更加精确的匹配。一个字段可以包含未被提取词干的版本，另一个则是含有变音符号的原始单词，然后第三个使用了shingles，用来提供和单词邻近度相关的信息。这些其它字段扮演的角色就是信号(Signals)，它们用来增加每个匹配文档的相关度分值。能够匹配的字段越多，相关度就越高。

```
POST /index1/resource/_search
{
  "query": {
    "multi_match": {
      "type":     "most_fields", 
      "query":    "王者",
      "fields": "title.cn"
    }
  }
}
```

[multi_match复杂查询](https://blog.csdn.net/zhanglh046/article/details/78536242)