#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
MT5 TCP Client - Versão de Produção
Copyright 2025, PerplexCoder

Cliente TCP para comunicação com MT5 Server
Suporta múltiplos comandos de trading e monitoramento
"""

import socket
import json
import time
import threading
import logging
from datetime import datetime
from typing import Dict, Any, Optional, List
import sys
import os

# Configuração de logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('mt5_client.log'),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)

class MT5TCPClient:
    """
    Cliente TCP para comunicação com MT5 Server
    
    Attributes:
        host (str): Endereço IP do servidor
        port (int): Porta do servidor
        socket (socket.socket): Socket de conexão
        connected (bool): Status da conexão
        auto_reconnect (bool): Reconexão automática
        heartbeat_interval (int): Intervalo de heartbeat em segundos
    """
    
    def __init__(self, host: str = "127.0.0.1", port: int = 9090, auto_reconnect: bool = True):
        """
        Inicializar cliente TCP
        
        Args:
            host (str): Endereço IP do servidor
            port (int): Porta do servidor
            auto_reconnect (bool): Habilitar reconexão automática
        """
        self.host = host
        self.port = port
        self.socket = None
        self.connected = False
        self.auto_reconnect = auto_reconnect
        self.heartbeat_interval = 30
        self.last_heartbeat = time.time()
        self.reconnect_attempts = 0
        self.max_reconnect_attempts = 5
        self.reconnect_delay = 5
        
        # Threading
        self.heartbeat_thread = None
        self.listener_thread = None
        self.running = False
        
        # Callbacks
        self.message_callbacks = []
        self.error_callbacks = []
        self.connection_callbacks = []
        
        logger.info(f"MT5 TCP Client inicializado - {host}:{port}")
    
    def connect(self) -> bool:
        """
        Conectar ao servidor MT5
        
        Returns:
            bool: True se conectado com sucesso
        """
        try:
            self.socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self.socket.settimeout(10)  # Timeout de 10 segundos
            
            logger.info(f"Conectando ao servidor {self.host}:{self.port}...")
            self.socket.connect((self.host, self.port))
            
            self.connected = True
            self.reconnect_attempts = 0
            self.running = True
            
            # Iniciar threads
            self._start_threads()
            
            logger.info("Conectado com sucesso ao servidor MT5")
            self._notify_connection_callbacks(True)
            
            return True
            
        except Exception as e:
            logger.error(f"Erro ao conectar: {e}")
            self.connected = False
            self._notify_error_callbacks(f"Erro de conexão: {e}")
            return False
    
    def disconnect(self):
        """
        Desconectar do servidor
        """
        logger.info("Desconectando do servidor...")
        
        self.running = False
        self.connected = False
        
        if self.socket:
            try:
                self.socket.close()
            except:
                pass
            self.socket = None
        
        # Aguardar threads terminarem
        if self.heartbeat_thread and self.heartbeat_thread.is_alive():
            self.heartbeat_thread.join(timeout=2)
        
        if self.listener_thread and self.listener_thread.is_alive():
            self.listener_thread.join(timeout=2)
        
        logger.info("Desconectado do servidor")
        self._notify_connection_callbacks(False)
    
    def _start_threads(self):
        """
        Iniciar threads de heartbeat e listener
        """
        # Thread de heartbeat
        self.heartbeat_thread = threading.Thread(target=self._heartbeat_worker, daemon=True)
        self.heartbeat_thread.start()
        
        # Thread de listener
        self.listener_thread = threading.Thread(target=self._message_listener, daemon=True)
        self.listener_thread.start()
    
    def _heartbeat_worker(self):
        """
        Worker thread para enviar heartbeat
        """
        while self.running and self.connected:
            try:
                if time.time() - self.last_heartbeat >= self.heartbeat_interval:
                    self.send_command("ping")
                    self.last_heartbeat = time.time()
                
                time.sleep(1)
                
            except Exception as e:
                logger.error(f"Erro no heartbeat: {e}")
                if self.auto_reconnect:
                    self._attempt_reconnect()
                break
    
    def _message_listener(self):
        """
        Worker thread para escutar mensagens do servidor
        """
        buffer = ""
        
        while self.running and self.connected:
            try:
                if not self.socket:
                    break
                
                data = self.socket.recv(4096).decode('utf-8')
                
                if not data:
                    logger.warning("Servidor desconectou")
                    self.connected = False
                    if self.auto_reconnect:
                        self._attempt_reconnect()
                    break
                
                buffer += data
                
                # Processar mensagens completas (separadas por \n)
                while '\n' in buffer:
                    line, buffer = buffer.split('\n', 1)
                    if line.strip():
                        self._process_message(line.strip())
                
            except socket.timeout:
                continue
            except Exception as e:
                logger.error(f"Erro ao receber mensagem: {e}")
                self.connected = False
                if self.auto_reconnect:
                    self._attempt_reconnect()
                break
    
    def _process_message(self, message: str):
        """
        Processar mensagem recebida do servidor
        
        Args:
            message (str): Mensagem JSON recebida
        """
        try:
            data = json.loads(message)
            logger.debug(f"Mensagem recebida: {data}")
            
            # Notificar callbacks
            self._notify_message_callbacks(data)
            
        except json.JSONDecodeError as e:
            logger.error(f"Erro ao decodificar JSON: {e} - Mensagem: {message}")
        except Exception as e:
            logger.error(f"Erro ao processar mensagem: {e}")
    
    def _attempt_reconnect(self):
        """
        Tentar reconectar ao servidor
        """
        if not self.auto_reconnect or self.reconnect_attempts >= self.max_reconnect_attempts:
            return
        
        self.reconnect_attempts += 1
        logger.info(f"Tentativa de reconexão {self.reconnect_attempts}/{self.max_reconnect_attempts}")
        
        time.sleep(self.reconnect_delay)
        
        if self.connect():
            logger.info("Reconexão bem-sucedida")
        else:
            logger.error(f"Falha na reconexão {self.reconnect_attempts}")
    
    def send_command(self, command: str, params: Dict[str, Any] = None) -> bool:
        """
        Enviar comando para o servidor
        
        Args:
            command (str): Comando a ser enviado
            params (Dict): Parâmetros do comando
            
        Returns:
            bool: True se enviado com sucesso
        """
        if not self.connected or not self.socket:
            logger.error("Não conectado ao servidor")
            return False
        
        try:
            message = {
                "action": command,
                "timestamp": int(time.time())
            }
            
            if params:
                message.update(params)
            
            json_message = json.dumps(message) + "\n"
            self.socket.send(json_message.encode('utf-8'))
            
            logger.debug(f"Comando enviado: {command}")
            return True
            
        except Exception as e:
            logger.error(f"Erro ao enviar comando: {e}")
            self.connected = False
            return False
    
    # Métodos de trading
    def get_market_data(self, symbol: str = "EURUSD") -> bool:
        """
        Solicitar dados de mercado
        
        Args:
            symbol (str): Símbolo do ativo
            
        Returns:
            bool: True se comando enviado
        """
        return self.send_command("get_market_data", {"symbol": symbol})
    
    def get_account_info(self) -> bool:
        """
        Solicitar informações da conta
        
        Returns:
            bool: True se comando enviado
        """
        return self.send_command("get_account_info")
    
    def get_positions(self) -> bool:
        """
        Solicitar posições abertas
        
        Returns:
            bool: True se comando enviado
        """
        return self.send_command("get_positions")
    
    def get_orders(self) -> bool:
        """
        Solicitar ordens pendentes
        
        Returns:
            bool: True se comando enviado
        """
        return self.send_command("get_orders")
    
    def place_order(self, symbol: str, order_type: str, volume: float, 
                   price: float = 0, sl: float = 0, tp: float = 0, 
                   comment: str = "") -> bool:
        """
        Colocar ordem de trading
        
        Args:
            symbol (str): Símbolo do ativo
            order_type (str): Tipo da ordem (buy, sell, buy_limit, sell_limit, etc.)
            volume (float): Volume da ordem
            price (float): Preço da ordem (para ordens limitadas)
            sl (float): Stop Loss
            tp (float): Take Profit
            comment (str): Comentário da ordem
            
        Returns:
            bool: True se comando enviado
        """
        params = {
            "symbol": symbol,
            "type": order_type,
            "volume": volume,
            "price": price,
            "sl": sl,
            "tp": tp,
            "comment": comment
        }
        
        return self.send_command("place_order", params)
    
    def close_position(self, ticket: int, volume: float = 0) -> bool:
        """
        Fechar posição
        
        Args:
            ticket (int): Ticket da posição
            volume (float): Volume a fechar (0 = fechar tudo)
            
        Returns:
            bool: True se comando enviado
        """
        params = {
            "ticket": ticket,
            "volume": volume
        }
        
        return self.send_command("close_position", params)
    
    def modify_order(self, ticket: int, price: float = 0, sl: float = 0, tp: float = 0) -> bool:
        """
        Modificar ordem
        
        Args:
            ticket (int): Ticket da ordem
            price (float): Novo preço
            sl (float): Novo Stop Loss
            tp (float): Novo Take Profit
            
        Returns:
            bool: True se comando enviado
        """
        params = {
            "ticket": ticket,
            "price": price,
            "sl": sl,
            "tp": tp
        }
        
        return self.send_command("modify_order", params)
    
    def cancel_order(self, ticket: int) -> bool:
        """
        Cancelar ordem pendente
        
        Args:
            ticket (int): Ticket da ordem
            
        Returns:
            bool: True se comando enviado
        """
        return self.send_command("cancel_order", {"ticket": ticket})
    
    def get_server_status(self) -> bool:
        """
        Solicitar status do servidor
        
        Returns:
            bool: True se comando enviado
        """
        return self.send_command("get_server_status")
    
    def get_symbols(self) -> bool:
        """
        Solicitar lista de símbolos
        
        Returns:
            bool: True se comando enviado
        """
        return self.send_command("get_symbols")
    
    def get_history(self, symbol: str, timeframe: str, start_time: int, end_time: int) -> bool:
        """
        Solicitar dados históricos
        
        Args:
            symbol (str): Símbolo do ativo
            timeframe (str): Timeframe (M1, M5, H1, etc.)
            start_time (int): Timestamp de início
            end_time (int): Timestamp de fim
            
        Returns:
            bool: True se comando enviado
        """
        params = {
            "symbol": symbol,
            "timeframe": timeframe,
            "start_time": start_time,
            "end_time": end_time
        }
        
        return self.send_command("get_history", params)
    
    # Métodos de callback
    def add_message_callback(self, callback):
        """
        Adicionar callback para mensagens recebidas
        
        Args:
            callback: Função callback(data)
        """
        self.message_callbacks.append(callback)
    
    def add_error_callback(self, callback):
        """
        Adicionar callback para erros
        
        Args:
            callback: Função callback(error_message)
        """
        self.error_callbacks.append(callback)
    
    def add_connection_callback(self, callback):
        """
        Adicionar callback para mudanças de conexão
        
        Args:
            callback: Função callback(connected: bool)
        """
        self.connection_callbacks.append(callback)
    
    def _notify_message_callbacks(self, data: Dict[str, Any]):
        """
        Notificar callbacks de mensagem
        
        Args:
            data: Dados da mensagem
        """
        for callback in self.message_callbacks:
            try:
                callback(data)
            except Exception as e:
                logger.error(f"Erro no callback de mensagem: {e}")
    
    def _notify_error_callbacks(self, error_message: str):
        """
        Notificar callbacks de erro
        
        Args:
            error_message: Mensagem de erro
        """
        for callback in self.error_callbacks:
            try:
                callback(error_message)
            except Exception as e:
                logger.error(f"Erro no callback de erro: {e}")
    
    def _notify_connection_callbacks(self, connected: bool):
        """
        Notificar callbacks de conexão
        
        Args:
            connected: Status da conexão
        """
        for callback in self.connection_callbacks:
            try:
                callback(connected)
            except Exception as e:
                logger.error(f"Erro no callback de conexão: {e}")


def message_handler(data):
    """
    Handler para mensagens recebidas do servidor
    
    Args:
        data: Dados da mensagem JSON
    """
    action = data.get('action', 'unknown')
    
    if action == 'welcome':
        logger.info(f"Bem-vindo ao servidor: {data.get('server', 'MT5 Server')}")
        logger.info(f"Símbolo: {data.get('symbol', 'N/A')}")
        logger.info(f"Magic Number: {data.get('magic_number', 'N/A')}")
    
    elif action == 'heartbeat':
        logger.debug(f"Heartbeat recebido - Clientes ativos: {data.get('active_clients', 0)}")
    
    elif action == 'market_data':
        market_data = data.get('data', {})
        logger.info(f"Dados de mercado - Bid: {market_data.get('bid')}, Ask: {market_data.get('ask')}")
    
    elif action == 'account_info':
        account_data = data.get('data', {})
        logger.info(f"Conta - Saldo: {account_data.get('balance')}, Equity: {account_data.get('equity')}")
    
    elif action == 'positions':
        positions = data.get('data', [])
        logger.info(f"Posições abertas: {len(positions)}")
        for pos in positions:
            logger.info(f"  Ticket: {pos.get('ticket')}, Símbolo: {pos.get('symbol')}, Volume: {pos.get('volume')}")
    
    elif action == 'orders':
        orders = data.get('data', [])
        logger.info(f"Ordens pendentes: {len(orders)}")
        for order in orders:
            logger.info(f"  Ticket: {order.get('ticket')}, Tipo: {order.get('type')}, Volume: {order.get('volume')}")
    
    elif action == 'trade_result':
        result = data.get('data', {})
        success = result.get('success', False)
        message = result.get('message', 'N/A')
        logger.info(f"Resultado da operação: {'Sucesso' if success else 'Falha'} - {message}")
    
    elif action == 'error':
        error_msg = data.get('message', 'Erro desconhecido')
        logger.error(f"Erro do servidor: {error_msg}")
    
    else:
        logger.info(f"Mensagem recebida: {action} - {data}")


def connection_handler(connected):
    """
    Handler para mudanças de conexão
    
    Args:
        connected: Status da conexão
    """
    if connected:
        logger.info("✓ Conectado ao servidor MT5")
    else:
        logger.warning("✗ Desconectado do servidor MT5")


def error_handler(error_message):
    """
    Handler para erros
    
    Args:
        error_message: Mensagem de erro
    """
    logger.error(f"Erro: {error_message}")


def interactive_menu(client: MT5TCPClient):
    """
    Menu interativo para testar o cliente
    
    Args:
        client: Instância do cliente MT5
    """
    while True:
        print("\n=== MT5 TCP Client - Menu Interativo ===")
        print("1. Dados de mercado")
        print("2. Informações da conta")
        print("3. Posições abertas")
        print("4. Ordens pendentes")
        print("5. Colocar ordem de compra")
        print("6. Colocar ordem de venda")
        print("7. Status do servidor")
        print("8. Lista de símbolos")
        print("9. Dados históricos")
        print("10. Ping")
        print("0. Sair")
        
        try:
            choice = input("\nEscolha uma opção: ").strip()
            
            if choice == '0':
                break
            elif choice == '1':
                symbol = input("Símbolo (EURUSD): ").strip() or "EURUSD"
                client.get_market_data(symbol)
            elif choice == '2':
                client.get_account_info()
            elif choice == '3':
                client.get_positions()
            elif choice == '4':
                client.get_orders()
            elif choice == '5':
                symbol = input("Símbolo (EURUSD): ").strip() or "EURUSD"
                volume = float(input("Volume (0.01): ").strip() or "0.01")
                client.place_order(symbol, "buy", volume)
            elif choice == '6':
                symbol = input("Símbolo (EURUSD): ").strip() or "EURUSD"
                volume = float(input("Volume (0.01): ").strip() or "0.01")
                client.place_order(symbol, "sell", volume)
            elif choice == '7':
                client.get_server_status()
            elif choice == '8':
                client.get_symbols()
            elif choice == '9':
                symbol = input("Símbolo (EURUSD): ").strip() or "EURUSD"
                timeframe = input("Timeframe (H1): ").strip() or "H1"
                start_time = int(time.time()) - 86400  # 24 horas atrás
                end_time = int(time.time())
                client.get_history(symbol, timeframe, start_time, end_time)
            elif choice == '10':
                client.send_command("ping")
            else:
                print("Opção inválida!")
                
            time.sleep(0.5)  # Pequena pausa para processar resposta
            
        except KeyboardInterrupt:
            break
        except Exception as e:
            logger.error(f"Erro no menu: {e}")


def main():
    """
    Função principal do cliente
    """
    print("=== MT5 TCP Client v2.00 ===")
    print("Copyright 2025, PerplexCoder")
    print("Cliente TCP para comunicação com MT5 Server\n")
    
    # Configurações do servidor
    host = input("IP do servidor (127.0.0.1): ").strip() or "127.0.0.1"
    port = int(input("Porta do servidor (9090): ").strip() or "9090")
    
    # Criar cliente
    client = MT5TCPClient(host, port)
    
    # Adicionar handlers
    client.add_message_callback(message_handler)
    client.add_connection_callback(connection_handler)
    client.add_error_callback(error_handler)
    
    try:
        # Conectar ao servidor
        if client.connect():
            print("\nConexão estabelecida com sucesso!")
            
            # Aguardar um pouco para receber mensagem de boas-vindas
            time.sleep(1)
            
            # Menu interativo
            interactive_menu(client)
        else:
            print("Falha ao conectar ao servidor")
    
    except KeyboardInterrupt:
        print("\nInterrompido pelo usuário")
    
    finally:
        # Desconectar
        client.disconnect()
        print("Cliente finalizado")


if __name__ == "__main__":
    main()