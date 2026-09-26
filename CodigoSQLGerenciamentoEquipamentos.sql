USE gerenciamento_equipamento;
select * from categoria_equipamento;
select * from equipamento;
select * from Usuarios;
select * from solicitacao_emprestimo;
drop trigger verificar_status_equipamento;

DELIMITER //
CREATE EVENT verificar_atrasos
ON SCHEDULE EVERY 1 MINUTE
DO
BEGIN
    UPDATE solicitacao_emprestimo
    SET status_solicitacao = 'Atraso'
    WHERE tempo_estimado_devolucao < CURRENT_TIMESTAMP()
      AND status_solicitacao <> 'Devolvido'
      AND status_solicitacao <> 'Atraso';

    UPDATE usuarios u
    INNER JOIN solicitacao_emprestimo s
        ON s.usuario_id = u.id_usuario
    SET u.status_usuario = 'Bloqueado'
    WHERE s.tempo_estimado_devolucao < CURRENT_TIMESTAMP()
      AND s.status_solicitacao = 'Atraso';

END//
DELIMITER ;

DELIMITER //
CREATE TRIGGER atualizar_data_aprovacao
BEFORE UPDATE ON solicitacao_emprestimo
FOR EACH ROW
BEGIN

    IF NEW.status_solicitacao = 'Aprovado'
       AND OLD.status_solicitacao <> 'Aprovado' THEN

        SET NEW.data_aprovacao = CURRENT_TIMESTAMP;

        SET NEW.tempo_estimado_devolucao =
            DATE_ADD(NEW.data_aprovacao, INTERVAL 5 DAY);

    ELSEIF NEW.status_solicitacao = 'Negado'
       AND OLD.status_solicitacao <> 'Negado' THEN

        SET NEW.data_aprovacao = CURRENT_TIMESTAMP;
        SET NEW.tempo_estimado_devolucao = NULL;

    ELSEIF NEW.status_solicitacao = 'Pendente' THEN

        SET NEW.data_aprovacao = NULL;
        SET NEW.tempo_estimado_devolucao = NULL;

    END IF;

END//
DELIMITER ;

DELIMITER //

CREATE TRIGGER verificar_status_equipamento
BEFORE INSERT ON solicitacao_emprestimo
FOR EACH ROW
BEGIN
    DECLARE status_equipamento_atual VARCHAR(50);
    DECLARE status_usuario_atual VARCHAR(50);

    SELECT status_equipamento
    INTO status_equipamento_atual
    FROM equipamento
    WHERE equipamento_id = NEW.equipamento_id;

    IF status_equipamento_atual <> 'Disponivel' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Empréstimo não permitido: equipamento não está disponível.';
    END IF;

    SELECT status_usuario
    INTO status_usuario_atual
    FROM usuarios
    WHERE id_usuario = NEW.usuario_id;

    IF status_usuario_atual <> 'Ativo' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Usuário não está ativo para fazer empréstimo.';
    END IF;

END//

DELIMITER ;

create table categoria_equipamento(
	categoria_id int auto_increment primary key,
    categoria_name varchar(100) not null unique
);

create table usuarios(
	id_usuario int auto_increment primary key,
    cpf varchar(11) unique not null,
    nome varchar(100) not null,
    email varchar(50) unique not null,
    senha varchar(255) not null,
    status_usuario enum('Ativo', 'Inativo', 'Bloqueado') default 'Ativo' not null,
    data_cadastro datetime default current_timestamp,
    perfil enum('Administrador', 'Gestor', 'Tecnico', 'Aluno') default 'Aluno' not null
);


create table equipamento(
	equipamento_id int auto_increment primary key,
    nome varchar(100) not null,
    patrimonio varchar(10) not null,
    marca varchar(100) not null,
    modelo varchar(100) not null,
    descricao text(255) not null,
    status_equipamento enum('Disponivel', 'Indisponivel', 'Manutencao', 'Reservado') default 'Disponivel' not null,
    equipamento_categoria_id int,
    foreign key(equipamento_categoria_id) references Categoria_equipamento(categoria_id)
);

CREATE TABLE solicitacao_emprestimo (
    id_solicitacao_emprestimo INT AUTO_INCREMENT PRIMARY KEY,
    status_solicitacao ENUM('Pendente','Aprovado','Negado','Atraso','Devolvido') DEFAULT 'Pendente' NOT NULL,
    data_solicitacao DATETIME DEFAULT CURRENT_TIMESTAMP NOT NULL,
    data_aprovacao DATETIME NULL,
    tempo_estimado_devolucao DATETIME NULL,
    equipamento_id INT NOT NULL,
    usuario_id INT NOT NULL,
    id_aprovador INT,

    FOREIGN KEY (id_aprovador) REFERENCES usuarios(id_usuario),
    FOREIGN KEY (equipamento_id) REFERENCES equipamento(equipamento_id),
    FOREIGN KEY (usuario_id) REFERENCES usuarios(id_usuario)
);


SHOW TRIGGERS LIKE 'solicitacao_emprestimo';