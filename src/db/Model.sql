-- =========================
-- CRIAÇÃO DO SCHEMA PRINCIPAL
-- =========================

CREATE DATABASE IF NOT EXISTS BuyPy;
USE BuyPy;

-- =========================
-- CRIAÇÃO DAS TABELAS PRINCIPAIS
-- =========================

CREATE TABLE Produto (
    id_produto INT AUTO_INCREMENT PRIMARY KEY,
    quantidade INT NOT NULL,
    preco DECIMAL(10,2) NOT NULL,
    taxa_iva DECIMAL(4,2) NOT NULL,
    popularidade INT CHECK (popularidade BETWEEN 1 AND 5),
    imagem VARCHAR(255),
    ativo BOOLEAN DEFAULT TRUE,
    descricao_inatividade TEXT
);

CREATE TABLE Livro (
    id_produto INT PRIMARY KEY,
    isbn VARCHAR(20),
    titulo VARCHAR(255),
    genero VARCHAR(50),
    editora VARCHAR(100),
    autor VARCHAR(100),
    data_publicacao DATE,
    FOREIGN KEY (id_produto) REFERENCES Produto(id_produto) ON DELETE CASCADE
);

CREATE TABLE ConsumivelEletronica (
    id_produto INT PRIMARY KEY,
    numero_serie VARCHAR(50),
    marca VARCHAR(100),
    modelo VARCHAR(100),
    especificacoes TEXT,
    tipo VARCHAR(50),
    FOREIGN KEY (id_produto) REFERENCES Produto(id_produto) ON DELETE CASCADE
);

CREATE TABLE Cliente (
    id_cliente INT AUTO_INCREMENT PRIMARY KEY,
    nome VARCHAR(100),
    apelido VARCHAR(100),
    email VARCHAR(150) UNIQUE,
    senha VARCHAR(255),
    morada VARCHAR(255),
    codigo_postal VARCHAR(20),
    cidade VARCHAR(100),
    pais VARCHAR(100),
    telefone VARCHAR(20),
    estado ENUM('ativo','inativo','bloqueado') DEFAULT 'ativo'
);

CREATE TABLE Encomenda (
    id_encomenda INT AUTO_INCREMENT PRIMARY KEY,
    id_cliente INT,
    data_hora DATETIME,
    metodo_expedicao VARCHAR(100),
    estado VARCHAR(50),
    numero_cartao VARCHAR(20),
    nome_titular VARCHAR(150),
    validade_cartao DATE,
    FOREIGN KEY (id_cliente) REFERENCES Cliente(id_cliente) ON DELETE SET NULL
);

CREATE TABLE ItemEncomenda (
    id_encomenda INT,
    id_produto INT,
    quantidade INT,
    PRIMARY KEY (id_encomenda, id_produto),
    FOREIGN KEY (id_encomenda) REFERENCES Encomenda(id_encomenda) ON DELETE CASCADE,
    FOREIGN KEY (id_produto) REFERENCES Produto(id_produto) ON DELETE CASCADE
);

CREATE TABLE Recomendacao (
    id_cliente INT,
    id_produto INT,
    data_recomendacao DATE,
    PRIMARY KEY (id_cliente, id_produto),
    FOREIGN KEY (id_cliente) REFERENCES Cliente(id_cliente) ON DELETE CASCADE,
    FOREIGN KEY (id_produto) REFERENCES Produto(id_produto) ON DELETE CASCADE
);

CREATE TABLE Operador (
    id_operador INT AUTO_INCREMENT PRIMARY KEY,
    nome VARCHAR(100),
    apelido VARCHAR(100),
    senha VARCHAR(255),
    email VARCHAR(150) UNIQUE
);

-- =========================
-- VIEWs
-- =========================

CREATE OR REPLACE VIEW vw_livros_ativos AS
SELECT 
    l.titulo, 
    p.preco, 
    p.quantidade, 
    p.popularidade
FROM Livro l
JOIN Produto p ON l.id_produto = p.id_produto
WHERE p.ativo = TRUE;

CREATE OR REPLACE VIEW vw_encomendas_completas AS
SELECT 
    e.id_encomenda,
    c.nome,
    c.apelido,
    e.data_hora,
    e.estado,
    SUM(p.preco * ie.quantidade) AS total_estimado
FROM Encomenda e
JOIN Cliente c ON e.id_cliente = c.id_cliente
JOIN ItemEncomenda ie ON e.id_encomenda = ie.id_encomenda
JOIN Produto p ON ie.id_produto = p.id_produto
GROUP BY e.id_encomenda, c.nome, c.apelido, e.data_hora, e.estado;

-- =========================
-- PROCEDURES, FUNCTIONS
-- =========================

DELIMITER //

CREATE PROCEDURE sp_atualizar_quantidade (
    IN pid INT,
    IN nova_qtd INT
)
BEGIN
    UPDATE Produto SET quantidade = nova_qtd WHERE id_produto = pid;
END //

CREATE FUNCTION fn_preco_com_iva(preco DECIMAL(10,2), taxa DECIMAL(4,2))
RETURNS DECIMAL(10,2)
DETERMINISTIC
BEGIN
    RETURN preco * (1 + taxa);
END //

CREATE PROCEDURE CreateOrder (
    IN p_id_cliente INT,
    IN p_metodo_expedicao VARCHAR(100),
    IN p_numero_cartao VARCHAR(20),
    IN p_nome_titular VARCHAR(150),
    IN p_validade_cartao DATE,
    OUT p_id_encomenda INT
)
BEGIN
    INSERT INTO Encomenda (id_cliente, data_hora, metodo_expedicao, estado, numero_cartao, nome_titular, validade_cartao)
    VALUES (p_id_cliente, NOW(), p_metodo_expedicao, 'pendente', p_numero_cartao, p_nome_titular, p_validade_cartao);
    SET p_id_encomenda = LAST_INSERT_ID();
END //

CREATE PROCEDURE AddProductToOrder (
    IN p_id_encomenda INT,
    IN p_id_produto INT,
    IN p_quantidade INT
)
BEGIN
    INSERT INTO ItemEncomenda (id_encomenda, id_produto, quantidade)
    VALUES (p_id_encomenda, p_id_produto, p_quantidade);
END //

CREATE PROCEDURE GetOrderTotal (
    IN p_id_encomenda INT,
    OUT p_total DECIMAL(10,2)
)
BEGIN
    SELECT SUM(p.preco * ie.quantidade) INTO p_total
    FROM ItemEncomenda ie
    JOIN Produto p ON ie.id_produto = p.id_produto
    WHERE ie.id_encomenda = p_id_encomenda;
END //

-- =========================
-- TRIGGERS
-- =========================

CREATE TRIGGER trg_atualiza_estoque
AFTER INSERT ON ItemEncomenda
FOR EACH ROW
BEGIN
    UPDATE Produto
    SET quantidade = quantidade - NEW.quantidade
    WHERE id_produto = NEW.id_produto;
END //

CREATE TRIGGER trg_estoque_zero
AFTER UPDATE ON Produto
FOR EACH ROW
BEGIN
    IF NEW.quantidade = 0 THEN
        UPDATE Produto SET ativo = FALSE, descricao_inatividade = 'Sem estoque' 
        WHERE id_produto = NEW.id_produto;
    END IF;
END //

CREATE TABLE LogAtualizacoes (
    id_log INT AUTO_INCREMENT PRIMARY KEY,
    tabela_afetada VARCHAR(50),
    operacao VARCHAR(10),
    data_execucao DATETIME,
    detalhes TEXT
);

CREATE TRIGGER trg_log_update_produto
AFTER UPDATE ON Produto
FOR EACH ROW
BEGIN
    INSERT INTO LogAtualizacoes (tabela_afetada, operacao, data_execucao, detalhes)
    VALUES ('Produto', 'UPDATE', NOW(), 
        CONCAT('Produto ID: ', NEW.id_produto, ' | Quantidade: ', NEW.quantidade));
END //

DELIMITER ;
