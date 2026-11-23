-- 분석 질문 3 : 고객은 다시 구매하는가, 첫 주문 경험이 영향을 주는가
-- 기준 : 배송 완료 주문, 고객은 customer_unique_id

-- 1. 고객별 주문 수 분포
with 고객주문 as (
    select c.customer_unique_id,
           count(distinct o.order_id) as 주문수
    from orders o
    join customers c on o.customer_id = c.customer_id
    where o.order_status = 'delivered'
    group by c.customer_unique_id
)
select 주문수, count(*) as 고객수
from 고객주문
group by 주문수
order by 주문수;

-- 2. 첫 주문 지연 여부별 재구매율
-- partition by 로 고객별 주문 순번을 매겨 첫 주문만 남긴다
with 고객주문 as (
    select c.customer_unique_id,
           case when o.order_delivered_customer_date > o.order_estimated_delivery_date
                then 1 else 0 end as 지연,
           row_number() over (partition by c.customer_unique_id
                              order by o.order_purchase_timestamp) as 순번,
           count(*) over (partition by c.customer_unique_id) as 총주문수
    from orders o
    join customers c on o.customer_id = c.customer_id
    where o.order_status = 'delivered'
)
select case when 지연 = 1 then '첫 주문 지연' else '첫 주문 정시' end as 구분,
       count(*) as 고객수,
       sum(case when 총주문수 >= 2 then 1 else 0 end) as 재구매고객,
       round(avg(case when 총주문수 >= 2 then 1.0 else 0 end) * 100, 2) as 재구매율
from 고객주문
where 순번 = 1
group by 구분;