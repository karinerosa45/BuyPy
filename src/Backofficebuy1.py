# Importar bibliotecas necessárias
import sys
from PySide6.QtWidgets import ( # type: ignore
    QApplication, QWidget, QVBoxLayout, QPushButton, QTextEdit,
    QTableWidget, QTableWidgetItem, QMessageBox, QLineEdit, QLabel, QHBoxLayout
)
import mysql.connector  # type: ignore # Biblioteca para conectar com MySQL
import csv  # Para exportar arquivos CSV

# Criar a janela principal
class MainWindow(QWidget):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Backoffice BuyPy")
        self.setGeometry(100, 100, 700, 400)
        self.layout = QVBoxLayout()

        # Botões
        self.btn_livros_ativos = QPushButton("Mostrar Livros Ativos")
        self.btn_atualizar_quantidade = QPushButton("Atualizar Quantidade")
        self.btn_calcular_iva = QPushButton("Calcular Preço com IVA")
        self.btn_exportar_csv = QPushButton("Exportar CSV")  # NOVO BOTÃO

        # Campos de entrada para atualizar quantidade
        self.input_id_produto = QLineEdit()
        self.input_nova_qtd = QLineEdit()
        linha1 = QHBoxLayout()
        linha1.addWidget(QLabel("ID Produto:"))
        linha1.addWidget(self.input_id_produto)
        linha1.addWidget(QLabel("Nova Quantidade:"))
        linha1.addWidget(self.input_nova_qtd)

        # Campos de entrada para cálculo com IVA
        self.input_preco = QLineEdit()
        self.input_taxa = QLineEdit()
        linha2 = QHBoxLayout()
        linha2.addWidget(QLabel("Preço:"))
        linha2.addWidget(self.input_preco)
        linha2.addWidget(QLabel("Taxa IVA (ex: 0.23):"))
        linha2.addWidget(self.input_taxa)

        # Tabela e saída
        self.tabela = QTableWidget()
        self.saida = QTextEdit()
        self.saida.setReadOnly(True)

        # Adiciona elementos no layout
        self.layout.addLayout(linha1)
        self.layout.addWidget(self.btn_atualizar_quantidade)
        self.layout.addLayout(linha2)
        self.layout.addWidget(self.btn_calcular_iva)
        self.layout.addWidget(self.btn_livros_ativos)
        self.layout.addWidget(self.btn_exportar_csv)  # NOVO BOTÃO NO LAYOUT
        self.layout.addWidget(self.tabela)
        self.layout.addWidget(QLabel("Resultado:"))
        self.layout.addWidget(self.saida)

        self.setLayout(self.layout)

        # Conectar os botões
        self.btn_livros_ativos.clicked.connect(self.mostrar_livros_ativos)
        self.btn_atualizar_quantidade.clicked.connect(self.atualizar_quantidade)
        self.btn_calcular_iva.clicked.connect(self.calcular_iva)
        self.btn_exportar_csv.clicked.connect(self.exportar_csvs)  # CONEXÃO NOVA

    # Função para conectar ao banco BuyPy
    def conectar(self):
        try:
            conexao = mysql.connector.connect(
                host="localhost",
                user="Wilson",  # ou outro usuário com acesso total
                password="Lmxy20#a",
                database="BuyPy"
            )
            return conexao
        except mysql.connector.Error as erro:
            QMessageBox.critical(self, "Erro", f"Erro de conexão: {erro}")
            return None

    # Mostrar os livros ativos usando a VIEW
    def mostrar_livros_ativos(self):
        db = self.conectar()
        if db:
            cursor = db.cursor()
            cursor.execute("SELECT * FROM vw_livros_ativos")
            dados = cursor.fetchall()

            self.tabela.setRowCount(len(dados))
            self.tabela.setColumnCount(4)
            self.tabela.setHorizontalHeaderLabels(["Título", "Preço", "Quantidade", "Popularidade"])

            for linha, row in enumerate(dados):
                for col, valor in enumerate(row):
                    self.tabela.setItem(linha, col, QTableWidgetItem(str(valor)))

            cursor.close()
            db.close()

    # Chamar procedure para atualizar quantidade
    def atualizar_quantidade(self):
        id_produto = self.input_id_produto.text()
        nova_qtd = self.input_nova_qtd.text()

        if not id_produto or not nova_qtd:
            QMessageBox.warning(self, "Aviso", "Preencha todos os campos.")
            return

        db = self.conectar()
        if db:
            cursor = db.cursor()
            try:
                cursor.callproc("sp_atualizar_quantidade", (int(id_produto), int(nova_qtd)))
                db.commit()
                self.saida.setText(f"Quantidade do produto {id_produto} atualizada para {nova_qtd}.")
            except Exception as e:
                QMessageBox.critical(self, "Erro", str(e))
            finally:
                cursor.close()
                db.close()

    # Calcular preço com IVA usando a função SQL
    def calcular_iva(self):
        preco = self.input_preco.text()
        taxa = self.input_taxa.text()

        if not preco or not taxa:
            QMessageBox.warning(self, "Aviso", "Preencha todos os campos.")
            return

        db = self.conectar()
        if db:
            cursor = db.cursor()
            try:
                cursor.execute("SELECT fn_preco_com_iva(%s, %s)", (preco, taxa))
                resultado = cursor.fetchone()
                self.saida.setText(f"Preço com IVA: {resultado[0]}")
            except Exception as e:
                QMessageBox.critical(self, "Erro", str(e))
            finally:
                cursor.close()
                db.close()

    # NOVA FUNÇÃO: Exportar dados de tabelas do banco para arquivos CSV
    def exportar_csvs(self):
        db = self.conectar()
        if db:
            cursor = db.cursor()
            tabelas = [
                "Cliente", "Produto", "Livro", "Autor", "LivroAutor",
                "ConsumivelEletronica", "Encomenda", "ItemEncomenda",
                "Recomendacao", "Operador"
            ]
            erros = []

            for tabela in tabelas:
                try:
                    cursor.execute(f"SELECT * FROM {tabela}")
                    dados = cursor.fetchall()
                    colunas = [desc[0] for desc in cursor.description]

                    with open(f"{tabela.lower()}.csv", "w", newline="", encoding="utf-8") as f:
                        writer = csv.writer(f)
                        writer.writerow(colunas)
                        writer.writerows(dados)
                except Exception as e:
                    erros.append(tabela)

            cursor.close()
            db.close()

            if not erros:
                QMessageBox.information(self, "Exportação", "Todos os CSVs foram exportados com sucesso!")
            else:
                QMessageBox.warning(self, "Exportação", f"Erro ao exportar: {', '.join(erros)}")


# --------- Iniciar o programa ---------
if __name__ == "__main__":
    app = QApplication(sys.argv)
    window = MainWindow()
    window.show()
    sys.exit(app.exec())
