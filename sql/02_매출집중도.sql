-- 분석 질문 1 : 매출이 어느 정도 소수 셀러에 집중되어 있는가
-- 기준 : 배송 완료 주문, 매출은 상품가(price) 기준

-- 1. 전체 규모
select count(distinct i.seller_id) as 셀러수,
       round(sum(i.price), 0) as 총매출
from items i
join orders o on i.order_id = o.order_id
where o.order_status = 'delivered';

-- 2. 매출 상위 셀러 10곳
select i.seller_id,
       round(sum(i.price), 0) as 매출,
       count(distinct i.order_id) as 주문수
from items i
join orders o on i.order_id = o.order_id
where o.order_status = 'delivered'
group by i.seller_id
order by 매출 desc
limit 10;

-- 3. 구간별 매출 비중
with 셀러매출 as (
    select i.seller_id, sum(i.price) as 매출
    from items i
    join orders o on i.order_id = o.order_id
    where o.order_status = 'delivered'
    group by i.seller_id
),
순위 as (
    select seller_id, 매출,
           row_number() over (order by 매출 desc) as 순위,
           count(*)   over () as 전체셀러수,
           sum(매출)  over () as 총매출
    from 셀러매출
)
select case when 순위 <= 전체셀러수 * 0.01 then '상위 1%'
            when 순위 <= 전체셀러수 * 0.05 then '상위 1~5%'
            when 순위 <= 전체셀러수 * 0.10 then '상위 5~10%'
            when 순위 <= 전체셀러수 * 0.20 then '상위 10~20%'
            else '하위 80%' end as 구간,
       count(*) as 셀러수,
       round(sum(매출), 0) as 구간매출,
       round(sum(매출) / max(총매출) * 100, 1) as 매출비중
from 순위
group by 구간
order by 매출비중 desc;