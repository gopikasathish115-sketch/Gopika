from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv

from google import genai
from google.genai import types

import os
import time
import random
import logging
from typing import List


# ============================================================
# ENVIRONMENT
# ============================================================

load_dotenv()


GEMINI_API_KEY = os.getenv(
    "GEMINI_API_KEY",
    ""
).strip()


GEMINI_MODEL = os.getenv(
    "GEMINI_MODEL",
    "gemini-3.8-flash"
).strip()


# Only use models known from your current setup.
# The second model is a fallback if the primary is unavailable.
GEMINI_FALLBACK_MODELS = [
    "gemini-3.7-flash",
]


# ============================================================
# CONFIGURATION
# ============================================================

MAX_RETRIES_PER_MODEL = 3

INITIAL_RETRY_DELAY = 2

MAX_RETRY_DELAY = 10


# ============================================================
# LOGGING
# ============================================================

logging.basicConfig(
    level=logging.INFO,
    format=(
        "%(asctime)s | "
        "%(levelname)s | "
        "%(message)s"
    ),
)

logger = logging.getLogger("pocketsmart")


# ============================================================
# FASTAPI
# ============================================================

app = FastAPI(
    title="PocketSmart AI API",
    version="2.0.0",
    description=(
        "Advanced Gemini-powered backend "
        "for PocketSmart AI."
    ),
)


# ============================================================
# CORS
# ============================================================

app.add_middleware(
    CORSMiddleware,

    allow_origins=[
        FRONTEND_ORIGIN
        if (
            FRONTEND_ORIGIN := os.getenv(
                "FRONTEND_ORIGIN",
                "http://localhost:5173"
            )
        )
        else "http://localhost:5173",

        "http://localhost:5173",
        "http://127.0.0.1:5173",
    ],

    allow_credentials=True,

    allow_methods=["*"],

    allow_headers=["*"],
)


# ============================================================
# GEMINI CLIENT
# ============================================================

client = None

if GEMINI_API_KEY:
    client = genai.Client(
        api_key=GEMINI_API_KEY
    )


# ============================================================
# IMPORT PROJECT SCHEMAS
# ============================================================

from .config import (
    BACKEND_HOST,
    BACKEND_PORT,
    SYSTEM_INSTRUCTIONS,
)

from .schemas import (
    ChatRequest,
    ChatResponse,
)


# ============================================================
# MODEL LIST
# ============================================================

def get_model_list() -> List[str]:

    models = [
        GEMINI_MODEL,
        *GEMINI_FALLBACK_MODELS,
    ]

    # Remove duplicates while preserving order.
    unique_models = []

    for model in models:

        if model and model not in unique_models:
            unique_models.append(model)

    return unique_models


# ============================================================
# ERROR CLASSIFICATION
# ============================================================

def is_temporary_error(error: Exception) -> bool:

    message = str(error).lower()

    temporary_patterns = [
        "503",
        "unavailable",
        "service unavailable",
        "temporarily",
        "high demand",
        "overloaded",
        "internal server error",
        "deadline exceeded",
        "timeout",
        "timed out",
        "connection reset",
        "connection aborted",
    ]

    return any(
        pattern in message
        for pattern in temporary_patterns
    )


def is_rate_limit_error(error: Exception) -> bool:

    message = str(error).lower()

    return (
        "429" in message
        or "rate limit" in message
        or "resource exhausted" in message
    )


def is_not_found_error(error: Exception) -> bool:

    message = str(error).lower()

    return (
        "404" in message
        or "not_found" in message
        or "not found" in message
        or "model" in message
        and "not available" in message
    )


# ============================================================
# BACKOFF
# ============================================================

def calculate_backoff(attempt: int) -> float:

    base_delay = (
        INITIAL_RETRY_DELAY
        * (2 ** attempt)
    )

    jitter = random.uniform(
        0,
        1
    )

    return min(
        base_delay + jitter,
        MAX_RETRY_DELAY,
    )


# ============================================================
# BUILD GEMINI CONTENT
# ============================================================

def build_contents(
    request: ChatRequest
):

    contents = []

    for message in request.messages:

        content = (
            message.content or ""
        ).strip()

        if not content:
            continue


        # User message
        if message.role == "user":

            contents.append(
                types.Content(
                    role="user",
                    parts=[
                        types.Part.from_text(
                            text=content
                        )
                    ],
                )
            )


        # Assistant/model message
        elif message.role == "assistant":

            contents.append(
                types.Content(
                    role="model",
                    parts=[
                        types.Part.from_text(
                            text=content
                        )
                    ],
                )
            )

    return contents


# ============================================================
# GEMINI REQUEST
# ============================================================

def request_gemini(
    model: str,
    contents,
):

    if client is None:

        raise RuntimeError(
            "Gemini client is not initialized."
        )


    for attempt in range(
        MAX_RETRIES_PER_MODEL
    ):

        try:

            logger.info(
                "Gemini request | "
                "model=%s | "
                "attempt=%s/%s",
                model,
                attempt + 1,
                MAX_RETRIES_PER_MODEL,
            )


            # IMPORTANT:
            # No tools/functions are supplied.
            # Automatic function calling is explicitly disabled.
            response = client.models.generate_content(

                model=model,

                contents=contents,

                config=types.GenerateContentConfig(

                    system_instruction=(
                        SYSTEM_INSTRUCTIONS
                    ),

                    automatic_function_calling=(
                        types.AutomaticFunctionCallingConfig(
                            disable=True
                        )
                    ),
                ),
            )


            answer = (
                response.text or ""
            ).strip()


            if not answer:

                raise RuntimeError(
                    "Gemini returned an empty response."
                )


            logger.info(
                "Gemini response successful | "
                "model=%s",
                model,
            )

            return answer


        except Exception as exc:

            logger.warning(
                "Gemini error | "
                "model=%s | "
                "attempt=%s | "
                "error=%s",
                model,
                attempt + 1,
                exc,
            )


            # Do not retry permanent model errors.
            if is_not_found_error(exc):

                raise


            # Retry temporary errors.
            if (
                is_temporary_error(exc)
                or is_rate_limit_error(exc)
            ):

                if (
                    attempt
                    < MAX_RETRIES_PER_MODEL - 1
                ):

                    delay = calculate_backoff(
                        attempt
                    )

                    logger.info(
                        "Retrying Gemini in %.2f seconds",
                        delay,
                    )

                    time.sleep(delay)

                    continue


            # No retries remaining.
            raise


# ============================================================
# ROOT
# ============================================================

@app.get("/")
def root():

    return {
        "name": "PocketSmart AI API",

        "status": "running",

        "provider": "Google Gemini",

        "primary_model": GEMINI_MODEL,

        "fallback_models": (
            GEMINI_FALLBACK_MODELS
        ),

        "version": "2.0.0",

        "docs": "/docs",
    }


# ============================================================
# HEALTH
# ============================================================

@app.get("/health")
def health():

    return {

        "status": "ok",

        "provider": "Google Gemini",

        "model": GEMINI_MODEL,

        "api_key_configured": bool(
            GEMINI_API_KEY
        ),

        "backend": "online",
    }


# ============================================================
# CHAT
# ============================================================

@app.post(
    "/api/chat",
    response_model=ChatResponse,
)
def chat(
    request: ChatRequest
):

    # --------------------------------------------------------
    # API KEY
    # --------------------------------------------------------

    if not GEMINI_API_KEY:

        raise HTTPException(

            status_code=500,

            detail=(
                "GEMINI_API_KEY is not configured. "
                "Add it to the root .env file."
            ),
        )


    # --------------------------------------------------------
    # CLIENT
    # --------------------------------------------------------

    if client is None:

        raise HTTPException(

            status_code=500,

            detail=(
                "Gemini client could not be initialized."
            ),
        )


    # --------------------------------------------------------
    # MESSAGES
    # --------------------------------------------------------

    if not request.messages:

        raise HTTPException(

            status_code=400,

            detail=(
                "At least one message is required."
            ),
        )


    # --------------------------------------------------------
    # CONTENT
    # --------------------------------------------------------

    contents = build_contents(
        request
    )


    if not contents:

        raise HTTPException(

            status_code=400,

            detail=(
                "No valid messages were provided."
            ),
        )


    # --------------------------------------------------------
    # MODELS
    # --------------------------------------------------------

    models = get_model_list()

    last_error = None


    # --------------------------------------------------------
    # TRY MODELS
    # --------------------------------------------------------

    for model in models:

        try:

            logger.info(
                "Trying Gemini model: %s",
                model,
            )


            answer = request_gemini(
                model=model,
                contents=contents,
            )


            return ChatResponse(
                message=answer
            )


        except Exception as exc:

            last_error = exc


            logger.warning(
                "Model failed | "
                "model=%s | "
                "error=%s",
                model,
                exc,
            )


            # ------------------------------------------------
            # Permanent model error
            # ------------------------------------------------

            if is_not_found_error(exc):

                continue


            # ------------------------------------------------
            # Temporary error
            # ------------------------------------------------

            if (
                is_temporary_error(exc)
                or is_rate_limit_error(exc)
            ):

                logger.info(
                    "Trying next Gemini model..."
                )

                continue


            # ------------------------------------------------
            # Unknown error
            # ------------------------------------------------

            raise HTTPException(

                status_code=502,

                detail=(
                    "Gemini request failed: "
                    f"{str(exc)}"
                ),
            ) from exc


    # ========================================================
    # ALL MODELS FAILED
    # ========================================================

    logger.error(
        "All Gemini models failed | "
        "last_error=%s",
        last_error,
    )


    raise HTTPException(

        status_code=503,

        detail=(
            "Gemini is temporarily unavailable. "
            "Please try again shortly."
        ),
    )


# ============================================================
# DEVELOPMENT SERVER
# ============================================================

if __name__ == "__main__":

    import uvicorn

    uvicorn.run(

        "app.main:app",

        host=BACKEND_HOST,

        port=BACKEND_PORT,

        reload=True,
    )