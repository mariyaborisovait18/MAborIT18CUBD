-- нулевой старт
drop schema public cascade;
create schema public;

-- 1) Таблицы (пример: система библиотеки)
-- Ааторы
create table authors (
    author_id serial primary key,
    name text not null unique
);
-- Книги
create table books (
    book_id serial primary key,
    title text not null unique
);
-- Таблица-связка
create table borrowings (
    borrowing_id serial primary key,
    book_id int not null references books(book_id) on delete cascade,
    borrower text not null,
    borrow_date date not null default current_date
);

-- 2) Создание ролей (пользователей) и паролей к ним
-- Владелец базы (например postgres) имеет полный доступ
create role reader login password 'reader123';
create role librarian login password 'librarian123';
create role manager login password 'manager123';

-- Дополнительно создаём группу staff
create role staff;

-- Добавляем пользователей в группу staff
grant staff to reader;
grant staff to librarian;
grant staff to manager;

-- 3) Настройка прав доступа
-- Сначала запрещаем всем доступ к таблицам
revoke all on authors from public;
revoke all on books from public;
revoke all on borrowings from public;

-- Reader: может только читать список книг и авторов
grant select on authors to reader;
grant select on books to reader;

-- Librarian: может читать и управлять таблицей borrowings (выдача книг)
grant select, insert, update, delete on borrowings to librarian;

-- Manager: может добавлять новых авторов и книги
grant select, insert on authors to manager;
grant select, insert on books to manager;

-- Группа staff: доступ на чтение таблиц
grant usage on schema public to reader;
grant usage on schema public to librarian;
grant usage on schema public to manager;

-- 4) Тестирование прав доступа
-- Для тестирования нужно подключаться под разными пользователями.
-- Нужно создать отдельные подключения reader/librarian/manager.

-- (ЧАСТИ КОДОВ ТЕСТОВ ВСТАВЛЯТЬ В ТЕ КОНСОЛИ, КОТОРЫЕ СОЗДАЮТСЯ ПРИ СМЕНЕ ТИПА ПОЛЬЗОВАТЕЛЯ)

-- Тест 1: пользователь reader
-- Может читать авторов и книги:
--   select * from authors;
--   select * from books;
-- Попытка вставки:
--   insert into authors(name) values ('Новый Автор'); -- ОШИБКА: нет прав

-- Тест 2: пользователь librarian
-- Может работать с таблицей borrowings:
--   select * from borrowings;
--   insert into borrowings(book_id, borrower) values (1,'Иван Иванов');
--   update borrowings set borrower='Мария Петрова' where borrowing_id=1;
--   delete from borrowings where borrowing_id=1;
-- Попытка вставки автора или книги:
--   insert into authors(name) values ('Автор'); -- ОШИБКА: нет прав

-- Тест 3: пользователь manager
-- Может добавлять новых авторов и книги:
--   insert into authors(name) values ('Мария Петрова');
--   insert into books(title) values ('Алгоритмы');
-- Может читать:
--   select * from authors;
--   select * from books;
-- Попытка удаления:
--   delete from authors where author_id=1; -- ОШИБКА: нет прав

-- Тест 4: владелец базы (например postgres)
-- Имеет полный доступ ко всем таблицам:
-- Можно выполнить все коды в текущей лабораторной работе
