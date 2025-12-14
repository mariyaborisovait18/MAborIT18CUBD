-- Нулевой старт: удаляем схему public со всеми объектами и создаём её заново
drop schema public cascade;
create schema public;

-- 1) Таблицы
-- Таблица авторов
create table authors (
    author_id serial primary key,                                         
    name text not null unique                                               
);

-- Таблица книг
create table books (
    book_id serial primary key,                                            
    title text not null unique                                              
);

-- Таблица-связка "автор–книга"
create table authorships (
    author_id int not null references authors(author_id) on delete cascade, -- внешний ключ на автора
    book_id int not null references books(book_id) on delete cascade,       -- внешний ключ на книгу
    role text,                                                              -- дополнительный атрибут, роль (автор, редактор, соавтор)
    primary key (author_id, book_id)                                        -- уникальная пара автор–книга
);

-- 2) Представление (без идентификаторов)
-- Показывает имя автора, название книги и роль, скрывая внутренние ID
create view author_book_view as
select
    a.name  as author_name,
    b.title as book_title,
    ab.role
from authorships ab
join authors a on ab.author_id = a.author_id
join books b on ab.book_id = b.book_id;

-- 3) Триггерные функции

-- INSERT: добавление новой строки в представление
-- Проверяем, есть ли автор с таким именем. Если нет — создаём.
-- Проверяем, есть ли книга с таким названием. Если нет — создаём.
-- Добавляем связь автор–книга в таблицу authorships.
-- Если связь уже существует, обновляем роль.
create or replace function insert_author_book()
returns trigger as $$
declare
    aid int;  -- идентификатор автора
    bid int;  -- идентификатор книги
begin
    -- ищем автора по имени
    select author_id into aid from authors where name = new.author_name;
    -- если не найден, то вставляем нового автора
    if aid is null then
        insert into authors(name) values (new.author_name)
        returning author_id into aid;
    end if;
    -- ищем книгу по названию
    select book_id into bid from books where title = new.book_title;
    -- если не найдена, то вставляем новую книгу
    if bid is null then
        insert into books(title) values (new.book_title)
        returning book_id into bid;
    end if;

    -- вставляем или обновляем связь автор–книга
    insert into authorships(author_id, book_id, role)
    values (aid, bid, new.role)
    on conflict (author_id, book_id) do update
    set role = excluded.role;

    return new; -- передаём вставленную строку для представления
end;
$$ language plpgsql;

-- UPDATE: обновление строки в представлении
-- Находим ID автора и книги по новым значениям.
-- Если не найдены — выдаём ошибку.
-- Обновляем роль в таблице authorships.
-- Если связь не найдена — выдаём ошибку.
create or replace function update_author_book()
returns trigger as $$
declare
    aid int;  -- идентификатор автора
    bid int;  -- идентификатор книги
begin
    -- ищем автора и книгу одним запросом
    select a.author_id, b.book_id
    into aid, bid
    from authors a, books b
    where a.name = new.author_name
      and b.title = new.book_title;
    -- если автор или книга не найдены — ошибка
    if aid is null or bid is null then
        raise exception 'невозможно обновить: автор или книга не найдены.';
    end if;
    -- обновляем роль в таблице-связке
    update authorships
    set role = new.role
    where author_id = aid and book_id = bid;
    -- если обновление не затронуло ни одной строки — ошибка
    if not found then
        raise exception 'связь автор-книга для обновления не найдена.';
    end if;
    return new; -- передаём обновлённую строку
end;
$$ language plpgsql;

-- DELETE: удаление строки из представления
-- Находим ID автора и книги по старым значениям.
-- Если не найдены — просто возвращаем старую строку (ничего не удаляем).
-- Удаляем связь автор–книга из таблицы authorships.
create or replace function delete_author_book()
returns trigger as $$
declare
    aid int;  -- идентификатор автора
    bid int;  -- идентификатор книги
begin
    -- ищем автора и книгу одним запросом
    select a.author_id, b.book_id
    into aid, bid
    from authors a, books b
    where a.name = old.author_name
      and b.title = old.book_title;
    -- если автор или книга не найдены — ничего не делаем
    if aid is null or bid is null then
        return old;
    end if;
    -- удаляем связь автор–книга
    delete from authorships
    where author_id = aid and book_id = bid;
    return old; -- передаём удалённую строку
end;
$$ language plpgsql;

-- 4) Привязка триггеров к представлению
-- INSTEAD OF - при операции над представлением выполняется указанная функция
create trigger trg_insert_author_book
instead of insert on author_book_view
for each row execute function insert_author_book();

create trigger trg_update_author_book
instead of update on author_book_view
for each row execute function update_author_book();

create trigger trg_delete_author_book
instead of delete on author_book_view
for each row execute function delete_author_book();

-- 5) Тестирование
-- Тест 1 - вставка нового автора и новой книги
insert into author_book_view(author_name, book_title, role)
values ('Мария Петрова', 'Алгоритмы', 'автор');

-- Тест 2 - вставка существующего автора с новой книгой
insert into author_book_view(author_name, book_title, role)
values ('Мария Петрова', 'Базы данных', 'автор');

-- Тест 3 - вставка нового автора для уже существующей книги
insert into author_book_view(author_name, book_title, role)
values ('Иван Иванов', 'Базы данных', 'редактор');

-- Тест 4 - обновление роли для существующей связи
update author_book_view
set role = 'соавтор'
where author_name = 'Иван Иванов' and book_title = 'Базы данных';

-- Тест 5 - удаление связи автор–книга
delete from author_book_view
where author_name = 'Мария Петрова' and book_title = 'Алгоритмы';

-- Проверка результатов
select * from author_book_view order by author_name, book_title;
select * from authors order by author_id;
select * from books order by book_id;
select * from authorships order by author_id, book_id;
