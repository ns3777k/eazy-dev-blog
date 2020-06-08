+++
title = "Редирект после авторизации в nginx"
date = "2020-06-09T00:13:50+03:00"
tags = ["nginx"]
+++

Сегодня немножко препарнем **nginx**.

Какое-то время назад столкнулся с интересным кейсом в конфигурации **nginx**. Кейс, казалось бы, простой - нужно
прикрутить *basic-авторизацию* на `location`:

```text
location = /check/ {
    satisfy all;
    
    allow x.x.x.x;
    allow y.y.y.y;
    deny all;
    
    auth_basic "Auth required";
    auth_basic_user_file /etc/nginx/passwords/base;
    
    return 302 /userid/;
}
```

Казалось бы все просто, но нет. Этот кусок конфига работает не так, как вы ожидаете 😏 Куралнем:

```shell script
$ curl -I localhost:9999
HTTP/1.1 302 Moved Temporarily
Location: http://localhost/userid/
```

А где, собственно, авторизация? Ответ, как всегда, можно [найти в документации](http://nginx.org/en/docs/dev/development_guide.html#http_phases) 😕

В **nginx** существуют фазы обработки запроса и фаза рерайта (`NGX_HTTP_SERVER_REWRITE_PHASE`) работает **ДО** фазы
авторизации (`NGX_HTTP_ACCESS_PHASE`).

Самое пора задуматься о рефакторинге приложения, но если что, вот грязный хак:

```text
location = /check/ {
    // ...
    error_page 404 = @do_stuff;
}

location @do_stuff {
    return 302 /userid/;
}
```
