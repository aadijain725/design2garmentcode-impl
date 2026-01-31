import argparse
import logging
import sys
from datetime import datetime
from nicegui import ui, Client

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler('/tmp/gui_detailed.log')
    ]
)
logger = logging.getLogger(__name__)

logger.info("="*50)
logger.info("Starting Design2GarmentCode GUI")
logger.info("="*50)

# Custom
from gui.callbacks import GUIState
import gui.error_pages
logger.info("GUI modules loaded")

# GPT
from lmm_utils.agent import Agent
import asyncio
logger.info("Loading AI agent with model...")
agent=Agent(model_init=True)
logger.info("AI agent loaded successfully")
@ui.page('/')
async def index(client: Client):
    global agent
    logger.info(f"New connection request from client")
    # Start the interface!
    gui_st = GUIState()
    gui_st.pattern_state.agent=agent
    logger.info(f"GUI state initialized: {gui_st.pattern_state.id}")

    # Connection end
    # https://github.com/zauberzeug/nicegui/discussions/1379
    try:
        # Increased timeout for Cloudflare tunnel connections
        await client.connected(timeout=30.0)
        logger.info(f"Client connected: {gui_st.pattern_state.id}")
        await client.disconnected()
        logger.info(f'Closed connection {gui_st.pattern_state.id}. Deleting files...')
        gui_st.release()
    except TimeoutError:
        # Handle timeout gracefully - likely a bot or incomplete connection
        logger.warning(f"Connection timeout for {gui_st.pattern_state.id}")
    except Exception as e:
        logger.error(f'Connection error: {e}')
        gui_st.release()

if __name__ == '__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument(
        '--host',
        help='Host address to start the gui server ,defaults to "127.0.0.0"',
        type=str,
        default='0.0.0.0'
    )
    parser.add_argument(
        '--port',
        help='Use this port',
        type=str,
        default="8080"
    )
    args=parser.parse_args()
    port = int(args.port)
    logger.info(f"Starting server on {args.host}:{port}")
    ui.run(
            host=args.host,
            port=port,
            reload=False,
            favicon='assets/img/favicon.ico',
            title='Design2GarmentCode: Turning Design Concepts to Tangible Garments Through Program Synthesis'
        )