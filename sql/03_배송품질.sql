-- 분석 질문 2 : 배송 지연이 어디서 발생하고 무엇에 영향을 주는가
-- 기준 : 배송 완료 주문, 지연 = 실제 수령일 > 배송 예정일

-- 1. 전체 지연율
select count(*) as 전체,
       sum(case when order_delivered_customer_date > order_estimated_delivery_date
                then 1 else 0 end) as 지연건수,
       round(avg(case when order_delivered_customer_date > order_estimated_delivery_date
                      then 1.0 else 0 end) * 100, 1) as 지연율
from orders
where order_status = 'delivered';

-- 2. 지연 여부별 리뷰 점수
-- 리뷰 중복이 있으므로 주문별 평균 점수로 1주문 = 1행을 만든 뒤 조인
with 주문리뷰 as (
    select order_id, avg(review_score) as 리뷰점수
    from reviews
    group by order_id
)
select case when o.order_delivered_customer_date > o.order_estimated_delivery_date
            then '지연' else '정시' end as 구분,
       count(*) as 건수,
       round(avg(r.리뷰점수), 2) as 평균점수,
       round(avg(case when r.리뷰점수 <= 2 then 1.0 else 0 end) * 100, 1) as 불만비율
from orders o
join 주문리뷰 r on o.order_id = r.order_id
where o.order_status = 'delivered'
group by 구분;

-- 3. 셀러별 매출과 지연율
-- items는 주문당 여러 행이므로 distinct로 주문 단위를 먼저 맞춘다
with 셀러주문 as (
    select distinct i.seller_id, i.order_id,
           case when o.order_delivered_customer_date > o.order_estimated_delivery_date
                then 1 else 0 end as 지연
    from items i
    join orders o on i.order_id = o.order_id
    where o.order_status = 'delivered'
),
셀러매출 as (
    select i.seller_id, sum(i.price) as 매출
    from items i
    join orders o on i.order_id = o.order_id
    where o.order_status = 'delivered'
    group by i.seller_id
)
select m.seller_id,
       round(m.매출, 0) as 매출,
       count(*) as 주문수,
       sum(s.지연) as 지연건수,
       round(avg(s.지연) * 100, 1) as 지연율
from 셀러주문 s
join 셀러매출 m on s.seller_id = m.seller_id
group by m.seller_id, m.매출
order by 매출 desc
limit 20;

-- 4. 사분면 : 매출 상위 5% x 지연율 평균(8.1%) 초과
with 셀러주문 as (
    select distinct i.seller_id, i.order_id,
           case when o.order_delivered_customer_date > o.order_estimated_delivery_date
                then 1 else 0 end as 지연
    from items i
    join orders o on i.order_id = o.order_id
    where o.order_status = 'delivered'
),
셀러매출 as (
    select i.seller_id, sum(i.price) as 매출
    from items i
    join orders o on i.order_id = o.order_id
    where o.order_status = 'delivered'
    group by i.seller_id
),
셀러지표 as (
    select m.seller_id, m.매출,
           count(*) as 주문수,
           sum(s.지연) as 지연건수,
           avg(s.지연) * 100 as 지연율,
           row_number() over (order by m.매출 desc) as 매출순위,
           count(*) over () as 전체셀러수
    from 셀러주문 s
    join 셀러매출 m on s.seller_id = m.seller_id
    group by m.seller_id, m.매출
)
select case when 매출순위 <= 전체셀러수 * 0.05 then '매출 상위 5%' else '그 외' end as 매출구간,
       case when 지연율 > 8.1 then '지연율 평균 초과' else '평균 이하' end as 품질구간,
       count(*) as 셀러수,
       round(sum(매출), 0) as 매출합계,
       sum(지연건수) as 지연주문합계
from 셀러지표
group by 매출구간, 품질구간
order by 매출합계 desc;

-- 5. 주문 규모별 지연율 : 소규모 셀러의 비율 지표 왜곡 확인
with 셀러주문 as (
    select distinct i.seller_id, i.order_id,
           case when o.order_delivered_customer_date > o.order_estimated_delivery_date
                then 1 else 0 end as 지연
    from items i
    join orders o on i.order_id = o.order_id
    where o.order_status = 'delivered'
)
select case when 주문수 = 1 then '1건'
            when 주문수 <= 5 then '2~5건'
            when 주문수 <= 20 then '6~20건'
            else '21건 이상' end as 주문규모,
       count(*) as 셀러수,
       round(avg(지연율), 1) as 평균지연율,
       sum(case when 지연율 = 100 then 1 else 0 end) as 지연율100
from (
    select seller_id, count(*) as 주문수, avg(지연) * 100 as 지연율
    from 셀러주문
    group by seller_id
)
group by 주문규모
order by 셀러수 desc;