-- Projeto TABD | Consultas analíticas sobre o DW (PostgreSQL 17)
-- Uma consulta por pergunta. Base: dw.fato_sociopolitica_arco + dimensões.

-- Visão de apoio: fato com nomes e anos resolvidos
CREATE OR REPLACE VIEW dw.vw_fato_arco AS
SELECT f.*, a.nome_arco, s.id_saga_origem, s.nome_saga,
       ti.ano AS ano_inicio, tf.ano AS ano_fim
FROM dw.fato_sociopolitica_arco f
JOIN dw.dim_arco  a  ON a.sk_arco   = f.sk_arco
JOIN dw.dim_saga  s  ON s.sk_saga   = f.sk_saga
JOIN dw.dim_tempo ti ON ti.sk_tempo = f.sk_tempo_inicio
JOIN dw.dim_tempo tf ON tf.sk_tempo = f.sk_tempo_fim;

-- Classificação de |r| (Cohen, 1992)
CREATE OR REPLACE FUNCTION dw.classe_r(r double precision) RETURNS text
LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE WHEN abs(r) >= 0.5 THEN 'forte' WHEN abs(r) >= 0.3 THEN 'moderada' ELSE 'fraca' END
$$;

-- P1: ISA médio por saga e amplitude
WITH s AS (
  SELECT id_saga_origem, nome_saga, sum(qtd_arcos) AS arcos, round(avg(isa_final), 3) AS isa_medio
  FROM dw.vw_fato_arco GROUP BY id_saga_origem, nome_saga)
SELECT *, max(isa_medio) OVER () - min(isa_medio) OVER () AS amplitude
FROM s ORDER BY isa_medio DESC;

-- P2: top 10 arcos por ISA e quantidade com ISA = 0
SELECT nome_arco, nome_saga, isa_final FROM dw.vw_fato_arco ORDER BY isa_final DESC, sk_arco LIMIT 10;
SELECT count(*) FILTER (WHERE isa_final = 0) AS arcos_isa_zero FROM dw.vw_fato_arco;

-- P3: ISA médio por ano de início + TTI
SELECT ano_inicio, count(*) AS arcos, round(avg(isa_final), 3) AS isa_medio
FROM dw.vw_fato_arco GROUP BY ano_inicio ORDER BY ano_inicio;
SELECT round(corr(ano_inicio, isa_final)::numeric, 3) AS tti,
       dw.classe_r(corr(ano_inicio, isa_final)) AS intensidade FROM dw.vw_fato_arco;

-- P4: capítulos × ISA
SELECT round(corr(qtd_capitulos, isa_final)::numeric, 3) AS r_cap_isa,
       dw.classe_r(corr(qtd_capitulos, isa_final)) AS intensidade FROM dw.vw_fato_arco;

-- P5: médias das dimensões por saga
SELECT nome_saga, round(avg(op_final),3) AS op, round(avg(des_final),3) AS des,
       round(avg(dis_final),3) AS dis, round(avg(res_final),3) AS res
FROM dw.vw_fato_arco GROUP BY id_saga_origem, nome_saga ORDER BY id_saga_origem;

-- P6: indicadores reais por ano de início
SELECT ano_inicio, round(avg(op_real),5) AS op_real, round(avg(des_real),5) AS des_real,
       round(avg(dis_real),5) AS dis_real, round(avg(part_civil_real),5) AS part_civil_real
FROM dw.vw_fato_arco GROUP BY ano_inicio ORDER BY ano_inicio;

-- P7 e P8: CAT por dimensão, ordenado por |r| (a primeira linha responde à P8)
WITH c AS (
  SELECT 'Opressão política' AS dimensao, corr(op_final, op_real) AS r FROM dw.vw_fato_arco
  UNION ALL SELECT 'Desigualdade social', corr(des_final, des_real) FROM dw.vw_fato_arco
  UNION ALL SELECT 'Discriminação', corr(dis_final, dis_real) FROM dw.vw_fato_arco
  UNION ALL SELECT 'Resistência coletiva', corr(res_final, part_civil_real) FROM dw.vw_fato_arco)
SELECT dimensao, round(r::numeric, 3) AS cat, dw.classe_r(r) AS intensidade,
       CASE WHEN r > 0 THEN 'positivo' ELSE 'negativo' END AS sentido,
       CASE WHEN abs(r) >= 0.3 THEN 'H1 sustentada' ELSE 'H1 não confirmada' END AS hipotese
FROM c ORDER BY abs(r) DESC;

-- P9: ISA × indicadores reais
SELECT round(corr(isa_final, op_real)::numeric,3) AS r_op_real,
       round(corr(isa_final, des_real)::numeric,3) AS r_des_real,
       round(corr(isa_final, dis_real)::numeric,3) AS r_dis_real,
       round(corr(isa_final, part_civil_real)::numeric,3) AS r_part_civil_real
FROM dw.vw_fato_arco;

-- Base de P10 e P11: grupos de convergência (mediana sobre os 32 arcos; "acima" = estritamente maior)
CREATE OR REPLACE VIEW dw.vw_convergencia AS
WITH m AS (
  SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY op_real) AS m_op,
         percentile_cont(0.5) WITHIN GROUP (ORDER BY des_real) AS m_des,
         percentile_cont(0.5) WITHIN GROUP (ORDER BY dis_real) AS m_dis,
         percentile_cont(0.5) WITHIN GROUP (ORDER BY part_civil_real) AS m_res
  FROM dw.fato_sociopolitica_arco),
d AS (
  SELECT f.nome_arco, f.ano_inicio, x.dimensao, x.nota, x.real, x.mediana
  FROM dw.vw_fato_arco f CROSS JOIN m
  CROSS JOIN LATERAL (VALUES
    ('Opressão política', f.op_final, f.op_real, m.m_op),
    ('Desigualdade social', f.des_final, f.des_real, m.m_des),
    ('Discriminação', f.dis_final, f.dis_real, m.m_dis),
    ('Resistência coletiva', f.res_final, f.part_civil_real, m.m_res)) AS x(dimensao, nota, real, mediana))
SELECT *, CASE WHEN nota >= 2 AND real > mediana THEN 'alto nos dois'
               WHEN nota >= 2 THEN 'só na obra'
               WHEN real > mediana THEN 'só no mundo real'
               ELSE 'baixo nos dois' END AS grupo
FROM d;

-- P10: arcos em convergência por ano de início
SELECT ano_inicio, dimensao, nome_arco, nota, round(real::numeric, 6) AS indicador_real
FROM dw.vw_convergencia WHERE grupo = 'alto nos dois' ORDER BY ano_inicio, dimensao;

-- P11: de cada 100 arcos, quantos em cada grupo (PAC = 'alto nos dois')
SELECT dimensao, grupo, count(*) AS arcos, round(100.0 * count(*) / 32, 2) AS por_100_arcos
FROM dw.vw_convergencia GROUP BY dimensao, grupo ORDER BY dimensao, grupo;

-- P12: sentido da tendência do ISA × indicadores reais
WITH t AS (
  SELECT corr(ano_inicio, isa_final) AS isa, corr(ano_inicio, op_real) AS op,
         corr(ano_inicio, des_real) AS des, corr(ano_inicio, dis_real) AS dis,
         corr(ano_inicio, part_civil_real) AS res FROM dw.vw_fato_arco)
SELECT serie, round(r::numeric, 3) AS r, CASE WHEN r > 0 THEN 'crescente' ELSE 'decrescente' END AS sentido,
       CASE WHEN serie = 'isa_final' THEN '—' WHEN sign(r) = sign(t.isa) THEN 'sim' ELSE 'não' END AS coincide_com_isa
FROM t CROSS JOIN LATERAL (VALUES ('isa_final', t.isa), ('op_real', t.op), ('des_real', t.des),
                                  ('dis_real', t.dis), ('part_civil_real', t.res)) AS v(serie, r);