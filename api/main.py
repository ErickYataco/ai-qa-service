import logging
import os

import httpx
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

logging.basicConfig(level=os.getenv("LOG_LEVEL", "INFO"))
logger = logging.getLogger("simple-api")

app = FastAPI(title="AI Q&A Service", version="1.0.0")

VLLM_BASE_URL = os.getenv("VLLM_BASE_URL", "http://vllm-router.vllm.svc.cluster.local")
MODEL_NAME = os.getenv("MODEL_NAME", "HuggingFaceTB/SmolLM2-135M-Instruct")
TIMEOUT = float(os.getenv("HTTP_TIMEOUT", "60"))


class AskRequest(BaseModel):
    question: str = Field(..., min_length=1, max_length=4000)


class AskResponse(BaseModel):
    answer: str
    model: str


@app.get("/health")
async def health():
    return {"status": "ok"}


@app.post("/ask", response_model=AskResponse)
async def ask(request: AskRequest):
    if not request.question.strip():
        raise HTTPException(status_code=400, detail="question is required")

    payload = {
        "model": MODEL_NAME,
        "messages": [
            {"role": "system", "content": "You are a concise and helpful assistant."},
            {"role": "user", "content": request.question},
        ],
        "max_tokens": 256,
        "temperature": 0.2,
    }

    try:
        async with httpx.AsyncClient(timeout=TIMEOUT) as client:
            response = await client.post(
                f"{VLLM_BASE_URL.rstrip('/')}/v1/chat/completions",
                json=payload,
            )
            response.raise_for_status()
            data = response.json()

        answer = data["choices"][0]["message"]["content"].strip()
        return AskResponse(answer=answer, model=MODEL_NAME)

    except httpx.TimeoutException as exc:
        logger.exception("Timeout calling vLLM")
        raise HTTPException(status_code=504, detail="vLLM timeout") from exc
    except httpx.HTTPStatusError as exc:
        logger.exception("vLLM returned error status")
        raise HTTPException(status_code=502, detail="vLLM upstream error") from exc
    except httpx.RequestError as exc:
        logger.exception("Failed to reach vLLM")
        raise HTTPException(status_code=502, detail="vLLM unreachable") from exc
    except (KeyError, IndexError, TypeError, ValueError) as exc:
        logger.exception("Unexpected vLLM response format")
        raise HTTPException(status_code=502, detail="invalid vLLM response") from exc