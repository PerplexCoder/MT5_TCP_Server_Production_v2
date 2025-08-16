#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Cliente de Teste Expandido para MT5 TCP Server
Testa funcionalidades avançadas: Bid/Ask, ordens, posições e informações da conta
"""

import socket
import json
import time
import threading
from datetime import datetime
from typing import Dict, List, Optional, Any

class ExpandedMT5TestClient:
    def __init__(self, host='127.0.0.1', port=5557):
        self.host = host
        self.port = port
        self.socket = None
        self.connected = False
        self.response_timeout = 10.0
        
    def connect(self) -> bool:
        """Conecta ao servidor MT5"""
        try:
            self.socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self.socket.settimeout(self.response_timeout)
            self.socket.connect((self.host, self.port))
            self.connected = True
            print(f"✅ Conectado ao MT5 Server em {self.host}:{self.port}")
            return True
        except Exception as e:
            print(f"❌ Erro ao conectar: {e}")
            return False
    
    def disconnect(self):
        """Desconecta do servidor"""
        if self.socket:
            try:
                self.socket.close()
            except:
                pass
            self.socket = None
            self.connected = False
            print("🔌 Desconectado do servidor")
    
    def send_command(self, command: str, params: Dict = None) -> Optional[Dict]:
        """Envia comando e recebe resposta"""
        if not self.connected:
            print("❌ Não conectado ao servidor")
            return None
        
        try:
            # Preparar mensagem
            message = {
                "command": command,
                "timestamp": datetime.now().isoformat()
            }
            if params:
                message.update(params)
            
            # Enviar
            json_message = json.dumps(message)
            self.socket.send(json_message.encode('utf-8'))
            
            # Receber resposta
            response_data = self.socket.recv(8192)
            if not response_data:
                print(f"❌ Nenhuma resposta recebida para comando: {command}")
                return None
            
            response_str = response_data.decode('utf-8').strip()
            if response_str:
                try:
                    return json.loads(response_str)
                except json.JSONDecodeError:
                    print(f"⚠️ Resposta não é JSON válido: {response_str[:100]}...")
                    return {"raw_response": response_str}
            
        except socket.timeout:
            print(f"⏱️ Timeout ao aguardar resposta para: {command}")
        except Exception as e:
            print(f"❌ Erro ao enviar comando {command}: {e}")
        
        return None
    
    def test_ping(self) -> bool:
        """Testa conectividade básica"""
        print("\n🏓 Testando PING...")
        response = self.send_command("ping")
        if response:
            print(f"✅ PONG recebido: {response}")
            return True
        else:
            print("❌ Falha no teste de ping")
            return False
    
    def test_market_data(self, symbols: List[str] = None) -> Dict:
        """Testa obtenção de dados de mercado com Bid/Ask"""
        if symbols is None:
            symbols = ["EURUSD", "GBPUSD", "USDJPY"]
        
        print(f"\n📊 Testando dados de mercado para símbolos: {symbols}")
        results = {}
        
        for symbol in symbols:
            print(f"\n📈 Obtendo dados para {symbol}...")
            response = self.send_command("market_data", {"symbol": symbol})
            
            if response and "data" in response:
                data = response["data"]
                results[symbol] = data
                
                print(f"  Symbol: {data.get('symbol', 'N/A')}")
                print(f"  Bid: {data.get('bid', 'N/A')}")
                print(f"  Ask: {data.get('ask', 'N/A')}")
                print(f"  Spread: {data.get('spread', 'N/A')}")
                print(f"  Last: {data.get('last', 'N/A')}")
                print(f"  Volume: {data.get('volume', 'N/A')}")
                print(f"  Time: {data.get('time', 'N/A')}")
                print(f"  Dígitos: {data.get('digits', 'N/A')}")
                print(f"  Ponto: {data.get('point', 'N/A')}")
                print(f"  Tamanho do tick: {data.get('tick_size', 'N/A')}")
                print(f"  Lote mínimo: {data.get('min_lot', 'N/A')}")
                print(f"  Lote máximo: {data.get('max_lot', 'N/A')}")
                print(f"  Passo do lote: {data.get('lot_step', 'N/A')}")
            else:
                print(f"  ❌ Falha ao obter dados para {symbol}")
                results[symbol] = None
        
        return results
    
    def test_account_info(self) -> Dict:
        """Testa informações detalhadas da conta"""
        print("\n💰 Testando informações da conta...")
        response = self.send_command("account_info")
        
        if response and "data" in response:
            data = response["data"]
            print(f"  Login: {data.get('login', 'N/A')}")
            print(f"  Nome: {data.get('name', 'N/A')}")
            print(f"  Servidor: {data.get('server', 'N/A')}")
            print(f"  Moeda: {data.get('currency', 'N/A')}")
            print(f"  Saldo: {data.get('balance', 'N/A')}")
            print(f"  Patrimônio: {data.get('equity', 'N/A')}")
            print(f"  Lucro: {data.get('profit', 'N/A')}")
            print(f"  Margem: {data.get('margin', 'N/A')}")
            print(f"  Margem livre: {data.get('margin_free', 'N/A')}")
            print(f"  Nível de margem: {data.get('margin_level', 'N/A')}%")
            print(f"  Alavancagem: 1:{data.get('leverage', 'N/A')}")
            print(f"  Negociação permitida: {data.get('trade_allowed', 'N/A')}")
            print(f"  Expert Advisor permitido: {data.get('trade_expert', 'N/A')}")
            print(f"  Ativos: {data.get('assets', 'N/A')}")
            print(f"  Passivos: {data.get('liabilities', 'N/A')}")
            print(f"  Comissão bloqueada: {data.get('commission_blocked', 'N/A')}")
            
            # Verificar dados essenciais
            essential_fields = ['balance', 'equity', 'margin', 'currency']
            missing_fields = [field for field in essential_fields if field not in data]
            
            if not missing_fields:
                print(f"  ✓ Todos os campos essenciais presentes")
            else:
                print(f"  ✗ Campos ausentes: {missing_fields}")
            
            return data
        else:
            print("❌ Falha ao obter informações da conta")
            return {}
    
    def test_history(self) -> Dict:
        """Testa obtenção do histórico de transações"""
        print("\n📜 Testando histórico de transações...")
        response = self.send_command("history")
        
        if response and "data" in response:
            data = response["data"]
            print(f"  Período: {data.get('from', 'N/A')} até {data.get('to', 'N/A')}")
            
            deals = data.get('deals', [])
            orders = data.get('orders', [])
            
            print(f"  📊 Total de negociações: {len(deals)}")
            print(f"  📋 Total de ordens: {len(orders)}")
            
            if deals:
                print("\n  🔄 Últimas negociações:")
                for i, deal in enumerate(deals[:5]):  # Mostrar apenas as 5 primeiras
                    print(f"    {i+1}. Ticket: {deal.get('ticket', 'N/A')}")
                    print(f"       Símbolo: {deal.get('symbol', 'N/A')}")
                    print(f"       Tipo: {deal.get('type', 'N/A')}")
                    print(f"       Volume: {deal.get('volume', 'N/A')}")
                    print(f"       Preço: {deal.get('price', 'N/A')}")
                    print(f"       Lucro: {deal.get('profit', 'N/A')}")
                    print(f"       Tempo: {deal.get('time', 'N/A')}")
                    print()
            
            if orders:
                print("  📝 Últimas ordens:")
                for i, order in enumerate(orders[:5]):  # Mostrar apenas as 5 primeiras
                    print(f"    {i+1}. Ticket: {order.get('ticket', 'N/A')}")
                    print(f"       Símbolo: {order.get('symbol', 'N/A')}")
                    print(f"       Tipo: {order.get('type', 'N/A')}")
                    print(f"       Volume inicial: {order.get('volume_initial', 'N/A')}")
                    print(f"       Preço: {order.get('price_open', 'N/A')}")
                    print(f"       Estado: {order.get('state', 'N/A')}")
                    print(f"       Tempo: {order.get('time_setup', 'N/A')}")
                    print()
            
            return data
        else:
            print("❌ Falha ao obter histórico")
            return {}
    
    def test_positions(self) -> List[Dict]:
        """Testa obtenção de posições abertas"""
        print("\n📍 Testando posições abertas...")
        response = self.send_command("positions")
        
        if response and "data" in response:
            positions = response["data"]
            if positions:
                print(f"  📊 {len(positions)} posição(ões) encontrada(s):")
                for i, pos in enumerate(positions, 1):
                    print(f"    Posição {i}:")
                    print(f"      Symbol: {pos.get('symbol', 'N/A')}")
                    print(f"      Tipo: {pos.get('type', 'N/A')}")
                    print(f"      Volume: {pos.get('volume', 'N/A')}")
                    print(f"      Preço Abertura: {pos.get('price_open', 'N/A')}")
                    print(f"      Preço Atual: {pos.get('price_current', 'N/A')}")
                    print(f"      Lucro: {pos.get('profit', 'N/A')}")
                    print(f"      Swap: {pos.get('swap', 'N/A')}")
                    print(f"      Ticket: {pos.get('ticket', 'N/A')}")
            else:
                print("  ℹ️ Nenhuma posição aberta encontrada")
            return positions
        else:
            print("❌ Falha ao obter posições")
            return []
    
    def test_orders(self) -> List[Dict]:
        """Testa obtenção de ordens ativas (pendentes)"""
        print("\n📋 Testando ordens ativas...")
        response = self.send_command("orders")
        
        if response and "data" in response:
            orders = response["data"]
            if orders:
                print(f"  📊 {len(orders)} ordem(ns) ativa(s) encontrada(s):")
                for i, order in enumerate(orders, 1):
                    print(f"    Ordem {i}:")
                    print(f"      Ticket: {order.get('ticket', 'N/A')}")
                    print(f"      Symbol: {order.get('symbol', 'N/A')}")
                    print(f"      Tipo: {order.get('type', 'N/A')}")
                    print(f"      Volume: {order.get('volume', 'N/A')}")
                    print(f"      Preço: {order.get('price_open', 'N/A')}")
                    print(f"      SL: {order.get('sl', 'N/A')}")
                    print(f"      TP: {order.get('tp', 'N/A')}")
                    print(f"      Estado: {order.get('state', 'N/A')}")
            else:
                print("  ℹ️ Nenhuma ordem ativa encontrada")
            return orders
        else:
            print("❌ Falha ao obter ordens")
            return []
    
    def test_place_market_order(self, symbol: str = "EURUSD", volume: float = 0.01, 
                               order_type: str = "buy") -> Dict:
        """Testa colocação de ordem a mercado"""
        print(f"\n🛒 Testando ordem a mercado: {order_type.upper()} {volume} {symbol}...")
        
        params = {
            "symbol": symbol,
            "volume": volume,
            "type": order_type,
            "comment": "Teste ordem mercado"
        }
        
        response = self.send_command("place_order", params)
        
        if response:
            if response.get("success"):
                print(f"  ✅ Ordem executada com sucesso!")
                print(f"  Ticket: {response.get('ticket', 'N/A')}")
                print(f"  Preço: {response.get('price', 'N/A')}")
            else:
                print(f"  ❌ Falha na execução: {response.get('error', 'Erro desconhecido')}")
            return response
        else:
            print("❌ Nenhuma resposta recebida")
            return {}
    
    def test_place_pending_order(self, symbol: str = "EURUSD", volume: float = 0.01,
                                order_type: str = "buy_limit", price: float = None) -> Dict:
        """Testa colocação de ordem pendente"""
        print(f"\n⏳ Testando ordem pendente: {order_type.upper()} {volume} {symbol}...")
        
        params = {
            "symbol": symbol,
            "volume": volume,
            "type": order_type,
            "comment": "Teste ordem pendente"
        }
        
        if price:
            params["price"] = price
        
        response = self.send_command("place_pending_order", params)
        
        if response:
            if response.get("success"):
                print(f"  ✅ Ordem pendente colocada com sucesso!")
                print(f"  Ticket: {response.get('ticket', 'N/A')}")
                print(f"  Preço: {response.get('price', 'N/A')}")
            else:
                print(f"  ❌ Falha na colocação: {response.get('error', 'Erro desconhecido')}")
            return response
        else:
            print("❌ Nenhuma resposta recebida")
            return {}
    
    def test_close_position(self, ticket: int) -> Dict:
        """Testa fechamento de posição"""
        print(f"\n❌ Testando fechamento da posição {ticket}...")
        
        params = {"ticket": ticket}
        response = self.send_command("close_position", params)
        
        if response:
            if response.get("success"):
                print(f"  ✅ Posição fechada com sucesso!")
                print(f"  Lucro: {response.get('profit', 'N/A')}")
            else:
                print(f"  ❌ Falha no fechamento: {response.get('error', 'Erro desconhecido')}")
            return response
        else:
            print("❌ Nenhuma resposta recebida")
            return {}
    
    def run_comprehensive_test(self):
        """Executa teste abrangente de todas as funcionalidades"""
        print("🚀 INICIANDO TESTE ABRANGENTE DO MT5 TCP SERVER")
        print("=" * 60)
        
        # 1. Conectar
        if not self.connect():
            return
        
        try:
            # 2. Teste básico de conectividade
            self.test_ping()
            
            # 3. Informações da conta
            account_info = self.test_account_info()
            
            # 4. Dados de mercado detalhados
            market_data = self.test_market_data(["EURUSD", "GBPUSD", "USDJPY", "XAUUSD"])
            
            # 5. Histórico de transações
            history = self.test_history()
            
            # 6. Posições abertas
            positions = self.test_positions()
            
            # 6. Ordens ativas
            orders = self.test_orders()
            
            # 7. Teste de ordem a mercado (apenas em conta demo)
            if account_info.get('server', '').lower().find('demo') != -1:
                print("\n⚠️ Conta demo detectada - testando ordens...")
                
                # Ordem de compra
                buy_result = self.test_place_market_order("EURUSD", 0.01, "buy")
                time.sleep(2)
                
                # Verificar posições após ordem
                new_positions = self.test_positions()
                
                # Se uma posição foi aberta, tentar fechar
                if new_positions and len(new_positions) > len(positions):
                    newest_position = new_positions[-1]
                    if newest_position.get('ticket'):
                        time.sleep(2)
                        self.test_close_position(newest_position['ticket'])
                
                # Teste de ordem pendente
                time.sleep(2)
                pending_result = self.test_place_pending_order("EURUSD", 0.01, "buy_limit", 1.0500)
                
            else:
                print("\n⚠️ Conta real detectada - pulando testes de ordens por segurança")
            
            print("\n✅ TESTE ABRANGENTE CONCLUÍDO COM SUCESSO!")
            
        except Exception as e:
            print(f"\n❌ Erro durante o teste: {e}")
        
        finally:
            self.disconnect()

def main():
    """Função principal"""
    client = ExpandedMT5TestClient()
    client.run_comprehensive_test()

if __name__ == "__main__":
    main()