-- Olist 마켓플레이스 분석 : 데이터 검증
-- 실행 환경 : DuckDB (CSV를 뷰로 등록해 조회)

-- 0. 뷰 등록
create view orders    as select * from read_csv_auto('data/olist_orders_dataset.csv');
create view customers as select * from read_csv_auto('data/olist_customers_dataset.csv');
create view items     as select * from read_csv_auto('data/olist_order_items_dataset.csv');
create view payments  as select * from read_csv_auto('data/olist_order_payments_dataset.csv');
create view reviews   as select * from read_csv_auto('data/olist_order_reviews_dataset.csv');
create view products  as select * from read_csv_auto('data/olist_products_dataset.csv');
create view sellers   as select * from read_csv_auto('data/olist_sellers_dataset.csv');

-- 1. 테이블별 기준 단위 확인 : 1행이 무엇인지 확인한 뒤 조인한다
select count(*) as 전체행수, count(distinct order_id) as 고유주문수 from orders;
select count(*) as 전체행수, count(distinct order_id) as 고유주문수 from items;
select count(*) as 전체행수, count(distinct order_id) as 고유주문수 from payments;
select count(*) as 전체행수,
       count(distinct order_id)  as 고유주문수,
       count(distinct review_id) as 고유리뷰수
from reviews;

-- 2. 고객 수 중복 : customer_id는 주문마다 부여되므로 고객 집계에 쓸 수 없다
select count(distinct customer_id)        as customer_id수,
       count(distinct customer_unique_id) as 실제고객수
from customers;

-- 3. 주문 상태 분포
select order_status, count(*) as 건수
from orders
group by order_status
order by 건수 desc;

-- 4. 상품 정보가 없는 주문 775건의 상태 확인
select order_status, count(*) as 건수
from orders
where order_id not in (select order_id from items)
group by order_status
order by 건수 desc;

-- 5. 분할 결제 분포 : 한 주문의 결제 횟수별 주문 수
select 결제횟수, count(*) as 주문수
from (
    select order_id, count(*) as 결제횟수
    from payments
    group by order_id
)
group by 결제횟수
order by 결제횟수;

-- 6. 결제 기록이 없는 주문 찾기
select *
from orders
where order_id not in (select order_id from payments);

-- 7. 주문 금액과 결제 금액 대사
with 주문금액 as (
    select order_id, sum(price + freight_value) as 주문합계
    from items group by order_id
),
결제금액 as (
    select order_id, sum(payment_value) as 결제합계
    from payments group by order_id
)
select case when b.결제합계 > a.주문합계 then '결제가 더 많음' else '결제가 더 적음' end as 구분,
       count(*) as 건수,
       round(min(abs(b.결제합계 - a.주문합계)), 2) as 최소차이,
       round(max(abs(b.결제합계 - a.주문합계)), 2) as 최대차이,
       round(sum(abs(b.결제합계 - a.주문합계)), 2) as 차이합계
from 주문금액 a
join 결제금액 b on a.order_id = b.order_id
where abs(b.결제합계 - a.주문합계) > 0.01   -- 소수점 오차 제외
group by 구분;

-- 8. 불일치 원인 확인 : 결제 수단과 할부 개월
with 주문금액 as (
    select order_id, sum(price + freight_value) as 주문합계
    from items group by order_id
),
결제금액 as (
    select order_id, sum(payment_value) as 결제합계
    from payments group by order_id
),
불일치 as (
    select a.order_id
    from 주문금액 a
    join 결제금액 b on a.order_id = b.order_id
    where abs(b.결제합계 - a.주문합계) > 0.01
)
select p.payment_type,
       count(*) as 건수,
       round(avg(p.payment_installments), 1) as 평균할부
from payments p
join 불일치 u on p.order_id = u.order_id
group by p.payment_type
order by 건수 desc;

-- 비교용 : 전체 기준 결제 수단과 할부 개월
select payment_type,
       count(*) as 건수,
       round(avg(payment_installments), 1) as 평균할부
from payments
group by payment_type
order by 건수 desc;