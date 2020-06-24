+++
title = "HPE_INVALID_CONSTANT в nodejs"
date = "2020-06-24T17:30:06+03:00"
tags = ["nodejs", "backend", "http"]
+++

По работе столкнулся с одним кейсом, о котором сегодня расскажу. Сервис был написан на **nodejs 10** и перед ним стоял
**nginx**. В какой-то момент, в **access.log** начали появляться ошибки `400 Bad Request`:

```text
127.0.0.1 - worker [20/Nov/2017:18:52:17 +0000] "GET /go/online _ HTTP/1.1" 400 188 "-" "Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:47.0) Gecko/20100101 Firefox/47.0"
```

А в **error.log** фигурировало сообщение: `...upstream prematurely closed connection while reading response header from upstream...`.

Анализ приложения и добавление дополнительного логирования ничего не дело. Приложение ничего не писало в лог, но
**nginx** по прежнему отдавал `400` на некоторые запросы. Утром их было на порядок больше (от 5 до 20 ошибок в минуту
при нагрузке 70 - 100 `rps`) чем ночью (1-2 ошибок).

В упрощенном виде, приложение выглядело так (нативная нода без фреймворка):

```javascript
const http = require('http');

const server = http.createServer((request, response) => {
    console.log(`serving ${request.url}`);
    response.end(`I'm from server`);
});

server.on('error', err => {
    console.error(err);
});

server.listen(3000, () => {
    console.log(`Server is listening on port 3000`);
});
```

Если посмотреть лог **nginx** и код приложения, то на первый взгляд все выглядит хорошо и если поднять такой локально и
курлануть тот же путь из лога командой `curl -s 127.1/go/online`, то ошибки не будет. В чем тогда проблема? 

Вышеприведенный код неправильно слушает ошибки. В **99%**, стандартом является слушать событие `error`, но это тот
случай, когда сервер, при ошибке, [эмиттит не error, а clientError](https://github.com/nodejs/node/blob/v10.21.0/lib/_http_server.js#L526).
После фикса, в лог начало сыпаться такое:

```text
{ Error: Parse Error, bytesParsed: 15, code: 'HPE_INVALID_CONSTANT', rawPacket: <Buffer 47 45 54 ...> }
```

Дело немного двинулось с места, но все равно, до конца не было понятно откуда взялась ошибка парсинга и только
после перевода буффера в строку, ситуация прояснилась:

```text
GET /go/onlinetest _ HTTP/1.1
Host: 127.1:3000
```

Оказалось, что в логе **nginx** пробел был не разделителем пути от другой части лога, а это была неэкранированная часть
пути. В таких случаях **nodejs** [отвечает сразу 400 Bad Request](https://github.com/nodejs/node/blob/v10.21.0/lib/_http_server.js#L528).

До, кажется, 9й версии, **nodejs** просто принудительно закрывал соединение и **nginx** думал, что апстрим упал 😕
[Фиксилось тут](https://github.com/nodejs/node/pull/15324).