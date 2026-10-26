-- Projeto TABD | Fonte One Piece (anexo 8.3 da primeira entrega).
-- IDs fixos preservam as referencias entre sagas e arcos em todas as execucoes.
-- Este seed so deve preencher a origem OLTP; nunca popula staging ou DW.
BEGIN;

INSERT INTO oltp.saga (id_saga, nome_saga) VALUES
    (1, 'East Blue'),
    (2, 'Alabasta'),
    (3, 'Ilha do Céu'),
    (4, 'Water 7'),
    (5, 'Thriller Bark'),
    (6, 'Marineford'),
    (7, 'Ilha dos Homens-Peixe'),
    (8, 'Dressrosa'),
    (9, 'Whole Cake'),
    (10, 'Wano'),
    (11, 'Final')
ON CONFLICT (id_saga) DO NOTHING;

INSERT INTO oltp.arco (id_arco,id_saga,nome_arco,qtd_capitulos,ano_inicio,ano_fim,op_final,des_final,dis_final,res_final,isa_final) VALUES
    (1, 1, 'Romance Dawn', 7, 1997, 1997, 0.5, 0, 0, 0, 0.5),
    (2, 1, 'Orange Town', 14, 1997, 1997, 1, 0.5, 0, 2, 3.5),
    (3, 1, 'Syrup Village', 20, 1998, 1998, 0, 0, 0, 0, 0),
    (4, 1, 'Baratie', 27, 1998, 1998, 0, 0, 1, 0.5, 1.5),
    (5, 1, 'Arlong Park', 27, 1998, 1999, 3, 1, 1, 2.5, 7.5),
    (6, 1, 'Loguetown', 5, 1999, 1999, 0, 0, 0, 0, 0),
    (7, 2, 'Reverse Mountain', 5, 1999, 1999, 0, 0, 0, 0, 0),
    (8, 2, 'Whisky Peak', 9, 1999, 1999, 0, 0, 0, 0, 0),
    (9, 2, 'Little Garden', 15, 1999, 2000, 0, 0, 0, 0, 0),
    (10, 2, 'Drum', 25, 2000, 2000, 3, 1.5, 2.5, 3, 10),
    (11, 2, 'Alabasta', 63, 2000, 2002, 2.5, 3, 0, 3, 8.5),
    (12, 3, 'Jaya', 19, 2002, 2002, 0, 0, 0.5, 0, 0.5),
    (13, 3, 'Skypiea', 66, 2002, 2003, 2, 0, 1, 1, 4),
    (14, 4, 'Long Ring Long Land', 19, 2003, 2004, 0, 0, 0, 0, 0),
    (15, 4, 'Water 7', 53, 2004, 2005, 0.5, 0, 0.5, 0, 1),
    (16, 4, 'Enies Lobby', 56, 2005, 2006, 3, 0, 1.5, 3, 7.5),
    (17, 4, 'Pós-Enies Lobby', 11, 2006, 2007, 0, 0, 0, 0, 0),
    (18, 5, 'Thriller Bark', 48, 2007, 2008, 0, 0, 0, 0, 0),
    (19, 6, 'Arquipélago de Sabaody', 24, 2008, 2008, 3, 3, 3, 0, 9),
    (20, 6, 'Ilha das Mulheres', 11, 2008, 2008, 0, 0, 0, 0, 0),
    (21, 6, 'Impel Down', 25, 2008, 2009, 1, 0, 0.5, 1, 2.5),
    (22, 6, 'Marineford', 31, 2009, 2010, 1.5, 0, 0.5, 2, 4),
    (23, 6, 'Pós Guerra', 17, 2010, 2010, 3, 3, 2.5, 1.5, 10),
    (24, 7, 'Retorno à Sabaody', 5, 2010, 2010, 0, 0, 0, 0, 0),
    (25, 7, 'Ilha dos Homens Peixe', 51, 2010, 2012, 2, 3, 3, 2.5, 10.5),
    (26, 8, 'Punk Hazard', 46, 2012, 2013, 0, 0.5, 0, 0, 0.5),
    (27, 8, 'Dressrosa', 102, 2013, 2015, 3, 1.5, 1.5, 3, 9),
    (28, 9, 'Zou', 23, 2015, 2016, 0, 0, 1, 0, 1),
    (29, 9, 'Whole Cake', 78, 2016, 2018, 1.5, 0, 0.5, 0, 2),
    (30, 9, 'Reverie', 6, 2018, 2018, 0.5, 0.5, 1, 2.5, 4.5),
    (31, 10, 'Wano', 149, 2018, 2022, 3, 3, 1, 3, 10),
    (32, 11, 'Egghead', 68, 2022, 2024, 3, 0, 2, 3, 8)
ON CONFLICT (id_arco) DO NOTHING;

-- Ajusta as sequences implicitamente associadas as colunas IDENTITY, mesmo com INSERTs de ID explicito.
SELECT setval(pg_get_serial_sequence('oltp.saga', 'id_saga'), (SELECT MAX(id_saga) FROM oltp.saga), true);
SELECT setval(pg_get_serial_sequence('oltp.arco', 'id_arco'), (SELECT MAX(id_arco) FROM oltp.arco), true);

COMMIT;
