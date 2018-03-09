# Rate Limiter Middleware
This will act as a throttle to limit the requests. The default request limit is 100 requests per hour.
We will be utilizing Redis to store the data.

## Setup
```
docker-compose build
docker-compose up
```

## Test
```
for i in {1..101}
do
curl -i http://localhost:3000/home/index
done
```

## Run Specs
```
docker-compose run app rspec -f doc
```

## Details
There will be a few headers that will be available in the response which will allow us to know the limit details.
```
{
  "X-Rate-Limit-Limit" =>  100,
  "X-Rate-Limit-Remaining" => '90',
  "X-Rate-Limit-Reset" => 1520575741
}
```

`X-Rate-Limit-Limit`: the maximum number of request limit. This can be configured in the Setup.
`X-Rate-Limit-Remaining`: the remaining number of request.
`X-Rate-Limit-Reset`: the time when the current rate limit window resets in UTC epoch seconds. This can be configured in the Setup as well.
