+++
title = "Закрытие Symfony Security Monitoring"
date = "2021-01-20T21:10:14+03:00"
tags = ["php", "symfony", "security"]
+++

Буквально [недавно я писал о том](https://blog.eazy-dev.com/2021/01/symfony-api-2/), как подключить к проекту практически штатную проверку зависимостей на
уязвимости. Тогда я упомянул про то, что [SensioLabs Security Checker](https://github.com/sensiolabs/security-checker) позволяет загружать лок-файл на удаленный
сервер с целью проверки, а штатный `security:check` не open source.

Недавно все изменилось. Сервис по проверке лок-файлов закрылся, а утилиту выложили в [open source](https://github.com/fabpot/local-php-security-checker). Как по
мне, идея была очень странная - брать деньги за пользование облачной проверкой лок-файла, учитывая, что все уязвимые версии находятся в открытом репозитории. Даже
если на старте это стоило 2 евро за 3 года :-)
