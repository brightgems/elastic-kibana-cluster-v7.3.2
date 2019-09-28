POST /_bulk
{ "create": { "_index": "index1", "_type": "resource", "_id": 1 } }
{ "title": "周星驰最新电影" }
{ "create": { "_index": "index1", "_type": "resource", "_id": 2 } }
{ "title": "周星驰最好看的新电影" }
{ "create": { "_index": "index1", "_type": "resource", "_id": 3 } }
{ "title": "周星驰最新电影，最好，新电影" }
{ "create": { "_index": "index1", "_type": "resource", "_id": 4 } }
{ "title": "最最最最好的新新新新电影" }
{ "create": { "_index": "index1", "_type": "resource", "_id": 5 } }
{ "title": "I'm not happy about the foxes" }

POST /index1/resource/_search
{
  "query": {
    "multi_match": {
      "type":     "most_fields", 
      "query":    "the最新游戏",
      "fields": [ "title", "title.cn", "title.en" ]
    }
  }
}