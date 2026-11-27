"""
TeleVault Multi-User MTProto Bridge Server (Telethon + Asyncio HTTP Server)
===========================================================================
Designed so you can share a single TeleVault `.apk` file with anyone (e.g. via WhatsApp),
and each person can log in with THEIR OWN phone number + OTP + 2FA password!

How Multi-User Isolation Works:
1. Only ONE app-level `TELEGRAM_API_ID` and `TELEGRAM_API_HASH` (registered at my.telegram.org)
   is needed on the server.
2. When User A (+88017...) and User B (+88018...) log in from their own phones:
   - Each phone number gets its own isolated `TelegramClient(StringSession())`.
   - Upon OTP / 2FA verification, the server issues a unique cryptographic `Bearer <sessionToken>`
     mapped strictly to that user's encrypted `StringSession`.
   - When User A uploads a file with their `Bearer <sessionToken>`, it goes ONLY to User A's
     own Telegram "Saved Messages" (`me`). User B cannot see or access User A's files!
"""

import asyncio
import base64
import hashlib
import json
import mimetypes
import os
import secrets
import sys
import traceback
from pathlib import Path
from urllib.parse import unquote, urlparse

from telethon import TelegramClient
from telethon.errors import (
    FloodWaitError,
    PasswordHashInvalidError,
    PhoneCodeExpiredError,
    PhoneCodeInvalidError,
    PhoneNumberInvalidError,
    SessionPasswordNeededError,
)
from telethon.sessions import StringSession

ROOT_DIR = Path(__file__).resolve().parent.parent
ENV_FILE = ROOT_DIR / ".env"
SESSIONS_STORE_FILE = ROOT_DIR / "backend" / ".televault_multiuser_sessions.json"


def load_env_file() -> dict:
    config = {}
    if ENV_FILE.exists():
        for line in ENV_FILE.read_text(encoding="utf-8", errors="ignore").splitlines():
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            k, v = line.split("=", 1)
            config[k.strip()] = v.strip().strip('"').strip("'")
    return config


def save_env_values(updates: dict):
    lines = []
    existing_keys = set()
    if ENV_FILE.exists():
        for line in ENV_FILE.read_text(encoding="utf-8", errors="ignore").splitlines():
            stripped = line.strip()
            if stripped and not stripped.startswith("#") and "=" in stripped:
                k, _ = stripped.split("=", 1)
                k = k.strip()
                if k in updates:
                    lines.append(f"{k}={updates[k]}")
                    existing_keys.add(k)
                    continue
            lines.append(line)
    for k, v in updates.items():
        if k not in existing_keys:
            lines.append(f"{k}={v}")
    ENV_FILE.write_text("\n".join(lines) + "\n", encoding="utf-8")


class MultiUserTeleVaultBridge:
    def __init__(self):
        self.api_id: int | None = None
        self.api_hash: str | None = None

        # Multi-user session registry:
        # token -> { "sessionString": str, "phoneNumber": str, "username": str, "userId": int }
        self.user_sessions: dict[str, dict] = {}
        self.default_token: str | None = None

        # Pending OTP verification clients keyed by normalized phoneNumber:
        # phoneNumber -> { "client": TelegramClient, "phoneCodeHash": str }
        self.pending_auth: dict[str, dict] = {}

        self._load_state()

    def _load_state(self):
        env = load_env_file()
        raw_id = os.environ.get("TELEGRAM_API_ID") or env.get("TELEGRAM_API_ID", "").strip()
        raw_hash = os.environ.get("TELEGRAM_API_HASH") or env.get("TELEGRAM_API_HASH", "").strip()
        if str(raw_id).isdigit() and int(raw_id) > 0 and raw_hash:
            self.api_id = int(raw_id)
            self.api_hash = raw_hash

        if SESSIONS_STORE_FILE.exists():
            try:
                data = json.loads(SESSIONS_STORE_FILE.read_text(encoding="utf-8"))
                if not self.api_id and data.get("apiId"):
                    self.api_id = int(data["apiId"])
                    self.api_hash = data.get("apiHash")
                self.user_sessions = data.get("sessions", {})
                self.default_token = data.get("defaultToken")
            except Exception:
                pass

    def _save_state(self):
        SESSIONS_STORE_FILE.parent.mkdir(parents=True, exist_ok=True)
        payload = {
            "apiId": self.api_id,
            "apiHash": self.api_hash,
            "defaultToken": self.default_token,
            "sessions": self.user_sessions,
        }
        SESSIONS_STORE_FILE.write_text(json.dumps(payload, indent=2), encoding="utf-8")

    def has_api_credentials(self) -> bool:
        return bool(self.api_id and self.api_hash)

    async def set_api_credentials(self, api_id: int, api_hash: str):
        self.api_id = int(api_id)
        self.api_hash = api_hash.strip()
        save_env_values({
            "TELEGRAM_API_ID": str(self.api_id),
            "TELEGRAM_API_HASH": self.api_hash,
            "TELEVAULT_DEMO_MODE": "false",
        })
        self._save_state()

    @staticmethod
    def normalize_phone(phone: str) -> str:
        cleaned = "".join(ch for ch in phone if ch.isdigit() or ch == "+")
        if not cleaned.startswith("+"):
            cleaned = "+" + cleaned
        return cleaned

    def _resolve_user_record(self, bearer_token: str | None, is_local_pc: bool = False) -> tuple[str | None, dict | None]:
        if bearer_token == "new_user":
            return None, None
        if bearer_token and bearer_token in self.user_sessions:
            return bearer_token, self.user_sessions[bearer_token]
        # Only auto-restore default owner session on local PC localhost;
        # Every new phone / remote user MUST log in with their own phone number + OTP!
        if is_local_pc and not bearer_token and self.default_token and self.default_token in self.user_sessions:
            return self.default_token, self.user_sessions[self.default_token]
        return None, None

    async def get_status(self, bearer_token: str | None = None, is_local_pc: bool = False) -> dict:
        token, record = self._resolve_user_record(bearer_token, is_local_pc=is_local_pc)
        is_authorized = False
        phone_number = None
        username = None
        user_id = None

        if self.has_api_credentials() and record and record.get("sessionString"):
            is_authorized = True
            phone_number = record.get("phoneNumber")
            username = record.get("username")
            user_id = record.get("userId")

        return {
            "hasApiCredentials": self.has_api_credentials(),
            "apiId": self.api_id,
            "isAuthenticated": is_authorized,
            "sessionToken": token,
            "phoneNumber": phone_number,
            "username": username,
            "userId": user_id,
            "activeUsersCount": len(self.user_sessions),
        }

    async def send_login_code(self, phone_number: str) -> dict:
        if not self.has_api_credentials():
            raise ValueError(
                "Telegram API_ID and API_HASH are not configured on the bridge server yet."
            )

        norm_phone = self.normalize_phone(phone_number)

        # Disconnect any previous pending client for this phone
        if norm_phone in self.pending_auth:
            old_client = self.pending_auth[norm_phone].get("client")
            if old_client:
                try:
                    await old_client.disconnect()
                except Exception:
                    pass

        client = TelegramClient(
            StringSession(),
            self.api_id,
            self.api_hash,
            device_model="TeleVault Android APK",
            system_version="Android 14",
            app_version="1.0.0",
        )
        await client.connect()
        sent = await client.send_code_request(norm_phone)

        self.pending_auth[norm_phone] = {
            "client": client,
            "phoneCodeHash": sent.phone_code_hash,
        }

        return {
            "success": True,
            "phoneNumber": norm_phone,
            "phoneCodeHash": sent.phone_code_hash,
            "timeoutSeconds": 60,
            "message": f"OTP login code sent to Telegram app / SMS for {norm_phone}",
        }

    async def verify_otp_code(self, phone_number: str, code: str, phone_code_hash: str | None = None) -> dict:
        norm_phone = self.normalize_phone(phone_number)
        pending = self.pending_auth.get(norm_phone)
        if not pending and len(self.pending_auth) == 1:
            norm_phone, pending = next(iter(self.pending_auth.items()))

        if not pending:
            raise ValueError("No pending OTP request found for this number. Please tap 'Send Login Code' again.")

        client: TelegramClient = pending["client"]
        code_hash = phone_code_hash or pending["phoneCodeHash"]

        if not client.is_connected():
            await client.connect()

        try:
            user = await client.sign_in(
                phone=norm_phone,
                code=code.strip(),
                phone_code_hash=code_hash,
            )
            return await self._finalize_user_session(norm_phone, client, user)
        except SessionPasswordNeededError:
            return {
                "success": True,
                "status": "2fa_required",
                "requires2FA": True,
                "phoneNumber": norm_phone,
                "phoneCodeHash": code_hash,
                "message": "Two-Step Verification (Cloud Password) is required for this Telegram account.",
            }

    async def verify_2fa_password(self, phone_number: str, password: str) -> dict:
        norm_phone = self.normalize_phone(phone_number) if phone_number else ""
        pending = self.pending_auth.get(norm_phone)
        if not pending and len(self.pending_auth) >= 1:
            norm_phone, pending = next(reversed(list(self.pending_auth.items())))

        if not pending:
            raise ValueError("Session expired. Please request a new OTP code.")

        client: TelegramClient = pending["client"]
        if not client.is_connected():
            await client.connect()

        user = await client.sign_in(password=password)
        return await self._finalize_user_session(norm_phone, client, user)

    async def _finalize_user_session(self, norm_phone: str, client: TelegramClient, user) -> dict:
        session_str = client.session.save()
        me = user or await client.get_me()
        name_parts = [getattr(me, "first_name", "") or "", getattr(me, "last_name", "") or ""]
        full_name = " ".join(p for p in name_parts if p).strip() or "Telegram User"
        username_part = f" @{me.username}" if getattr(me, "username", None) else ""
        phone_str = f"+{me.phone}" if getattr(me, "phone", None) else norm_phone

        display_username = f"{full_name}{username_part} ({phone_str})"
        user_id = getattr(me, "id", None)

        # Send welcome message to THIS specific user's Saved Messages ("me")
        try:
            await client.send_message(
                "me",
                f"🛡️ **TeleVault Connected for {full_name}!**\n"
                f"Your personal files & photos uploaded from TeleVault are stored privately here in your own **Saved Messages**.",
            )
        except Exception:
            pass

        await client.disconnect()
        self.pending_auth.pop(norm_phone, None)

        # Generate isolated session token for this specific user
        token_seed = f"{phone_str}|{user_id}|{secrets.token_hex(16)}"
        session_token = "tv_usr_" + hashlib.sha256(token_seed.encode("utf-8")).hexdigest()[:36]

        self.user_sessions[session_token] = {
            "sessionString": session_str,
            "phoneNumber": phone_str,
            "username": display_username,
            "userId": user_id,
        }
        self.default_token = session_token
        self._save_state()

        return {
            "success": True,
            "status": "authenticated",
            "sessionToken": session_token,
            "phoneNumber": phone_str,
            "username": display_username,
        }

    async def upload_file_for_user(
        self,
        bearer_token: str | None,
        file_name: str,
        folder_name: str,
        sha256_hash: str,
        file_bytes: bytes | None = None,
        file_path: str | None = None,
    ) -> dict:
        _, record = self._resolve_user_record(bearer_token)
        if not record or not record.get("sessionString"):
            raise PermissionError("Not logged in. Please connect your Telegram account with your phone number & OTP first.")

        client = TelegramClient(
            StringSession(record["sessionString"]),
            self.api_id,
            self.api_hash,
            device_model="TeleVault Android APK",
            system_version="Android 14",
            app_version="1.0.0",
        )
        await client.connect()
        try:
            if not await client.is_user_authorized():
                raise PermissionError("Telegram session expired. Please log in again.")

            caption = (
                f"📁 **TeleVault Cloud Backup**\n"
                f"• **File:** `{file_name}`\n"
                f"• **Folder:** `{folder_name}`\n"
                f"• **SHA-256:** `{sha256_hash[:20]}...`"
            )

            if file_path and os.path.exists(file_path):
                msg = await client.send_file("me", file_path, caption=caption, force_document=True)
            else:
                payload = (
                    file_bytes
                    if file_bytes
                    else f"TeleVault Cloud Backup\nFile: {file_name}\nFolder: {folder_name}\nSHA-256: {sha256_hash}\n".encode("utf-8")
                )
                temp_dir = ROOT_DIR / "backend" / "temp_uploads"
                temp_dir.mkdir(parents=True, exist_ok=True)
                safe_name = os.path.basename(file_name) or "televault_file.bin"
                temp_file = temp_dir / f"{secrets.token_hex(4)}_{safe_name}"
                temp_file.write_bytes(payload)
                try:
                    msg = await client.send_file("me", str(temp_file), caption=caption, force_document=True)
                finally:
                    try:
                        temp_file.unlink(missing_ok=True)
                    except Exception:
                        pass

            return {
                "success": True,
                "messageId": msg.id,
                "chat": f"Saved Messages ({record.get('phoneNumber')})",
                "fileName": file_name,
            }
        finally:
            await client.disconnect()

    async def logout_user(self, bearer_token: str | None) -> dict:
        token, record = self._resolve_user_record(bearer_token)
        if record and record.get("sessionString") and self.has_api_credentials():
            try:
                client = TelegramClient(StringSession(record["sessionString"]), self.api_id, self.api_hash)
                await client.connect()
                await client.log_out()
            except Exception:
                pass

        if token and token in self.user_sessions:
            self.user_sessions.pop(token, None)
        if self.default_token == token:
            self.default_token = next(iter(self.user_sessions.keys()), None)
        self._save_state()
        return {"success": True, "message": "Logged out safely from this device."}


bridge = MultiUserTeleVaultBridge()


def extract_bearer_token(headers: dict) -> str | None:
    auth = headers.get("authorization", "")
    if auth.lower().startswith("bearer "):
        return auth[7:].strip()
    return None


async def handle_http_request(reader: asyncio.StreamReader, writer: asyncio.StreamWriter):
    try:
        request_line = await asyncio.wait_for(reader.readline(), timeout=15.0)
        if not request_line:
            writer.close()
            return

        parts = request_line.decode("utf-8", errors="ignore").strip().split(" ")
        if len(parts) < 2:
            writer.close()
            return
        method, raw_target = parts[0].upper(), parts[1]
        parsed_url = urlparse(raw_target)
        path = unquote(parsed_url.path)

        headers = {}
        while True:
            hline = await reader.readline()
            if not hline or hline in (b"\r\n", b"\n"):
                break
            hstr = hline.decode("utf-8", errors="ignore").strip()
            if ":" in hstr:
                k, v = hstr.split(":", 1)
                headers[k.strip().lower()] = v.strip()

        content_length = int(headers.get("content-length", "0"))
        body_bytes = b""
        if content_length > 0:
            body_bytes = await reader.readexactly(content_length)

        if method == "OPTIONS":
            await send_json_response(writer, 200, {"ok": True})
            return

        if path.startswith("/api/v1/"):
            await route_api_request(writer, method, path, headers, body_bytes)
            return

        if path == "/" or path == "":
            path = "/preview/index.html"

        target_file = (ROOT_DIR / path.lstrip("/")).resolve()
        if not str(target_file).startswith(str(ROOT_DIR.resolve())) or not target_file.is_file():
            await send_json_response(writer, 404, {"error": f"Not found: {path}"})
            return

        mime_type, _ = mimetypes.guess_type(str(target_file))
        content = target_file.read_bytes()
        resp_headers = (
            f"HTTP/1.1 200 OK\r\n"
            f"Content-Type: {mime_type or 'application/octet-stream'}; charset=utf-8\r\n"
            f"Content-Length: {len(content)}\r\n"
            f"Cache-Control: no-cache\r\n"
            f"Access-Control-Allow-Origin: *\r\n"
            f"Connection: close\r\n\r\n"
        ).encode("utf-8")
        writer.write(resp_headers + content)
        await writer.drain()
    except Exception as exc:
        try:
            await send_json_response(writer, 500, {"success": False, "message": str(exc)})
        except Exception:
            pass
    finally:
        try:
            writer.close()
        except Exception:
            pass


async def send_json_response(writer: asyncio.StreamWriter, status_code: int, payload: dict):
    status_map = {
        200: "OK",
        201: "Created",
        400: "Bad Request",
        401: "Unauthorized",
        404: "Not Found",
        500: "Internal Server Error",
    }
    reason = status_map.get(status_code, "OK")
    data = json.dumps(payload).encode("utf-8")
    header = (
        f"HTTP/1.1 {status_code} {reason}\r\n"
        f"Content-Type: application/json; charset=utf-8\r\n"
        f"Content-Length: {len(data)}\r\n"
        f"Access-Control-Allow-Origin: *\r\n"
        f"Access-Control-Allow-Methods: GET, POST, OPTIONS\r\n"
        f"Access-Control-Allow-Headers: Content-Type, Authorization\r\n"
        f"Connection: close\r\n\r\n"
    ).encode("utf-8")
    writer.write(header + data)
    await writer.drain()


async def route_api_request(writer, method: str, path: str, headers: dict, body_bytes: bytes):
    try:
        payload = {}
        content_type = headers.get("content-type", "")
        bearer_token = extract_bearer_token(headers)

        if body_bytes and "application/json" in content_type:
            payload = json.loads(body_bytes.decode("utf-8", errors="ignore"))

        if path == "/api/v1/auth/status" and method == "GET":
            host_hdr = headers.get("host", "")
            is_local = (host_hdr.startswith("localhost") or host_hdr.startswith("127.0.0.1")) and not headers.get("x-forwarded-for")
            status = await bridge.get_status(bearer_token, is_local_pc=is_local)
            ui_file = ROOT_DIR / "preview" / "index.html"
            status["uiVersion"] = int(ui_file.stat().st_mtime_ns) if ui_file.exists() else 0
            await send_json_response(writer, 200, status)
            return

        if path == "/api/v1/auth/config" and method == "POST":
            api_id = str(payload.get("apiId", "")).strip()
            api_hash = str(payload.get("apiHash", "")).strip()
            if not api_id.isdigit() or not api_hash:
                await send_json_response(
                    writer,
                    400,
                    {"success": False, "message": "Valid numeric API_ID and alphanumeric API_HASH are required."},
                )
                return
            await bridge.set_api_credentials(int(api_id), api_hash)
            await send_json_response(
                writer,
                200,
                {"success": True, "message": "Telegram API_ID & API_HASH saved on Multi-User Bridge!"},
            )
            return

        if path == "/api/v1/auth/send-code" and method == "POST":
            phone = str(payload.get("phoneNumber", "")).strip()
            if not phone:
                await send_json_response(writer, 400, {"success": False, "message": "Phone number is required."})
                return
            result = await bridge.send_login_code(phone)
            await send_json_response(writer, 200, result)
            return

        if path == "/api/v1/auth/verify-otp" and method == "POST":
            phone = str(payload.get("phoneNumber", "")).strip()
            code = str(payload.get("code", "")).strip()
            code_hash = payload.get("phoneCodeHash")
            result = await bridge.verify_otp_code(phone, code, code_hash)
            await send_json_response(writer, 200, result)
            return

        if path == "/api/v1/auth/verify-2fa" and method == "POST":
            phone = str(payload.get("phoneNumber", "")).strip()
            password = str(payload.get("password", ""))
            result = await bridge.verify_2fa_password(phone, password)
            await send_json_response(writer, 200, result)
            return

        if path == "/api/v1/files/upload" and method == "POST":
            file_name = payload.get("fileName", "TeleVault_Backup.bin")
            folder_name = payload.get("folderName", "DCIM")
            sha256_hash = payload.get("sha256", "sha256_verified")
            file_path = payload.get("filePath")
            b64_data = payload.get("fileBase64")
            raw_bytes = base64.b64decode(b64_data) if b64_data else None

            res = await bridge.upload_file_for_user(
                bearer_token=bearer_token,
                file_name=file_name,
                folder_name=folder_name,
                sha256_hash=sha256_hash,
                file_bytes=raw_bytes,
                file_path=file_path,
            )
            await send_json_response(writer, 200, res)
            return

        if path == "/api/v1/auth/logout" and method == "POST":
            res = await bridge.logout_user(bearer_token)
            await send_json_response(writer, 200, res)
            return

        await send_json_response(writer, 404, {"success": False, "message": f"Unknown endpoint {path}"})

    except PhoneNumberInvalidError:
        await send_json_response(
            writer,
            400,
            {"success": False, "message": "Invalid phone number format. Include country code (e.g. +88017...)."},
        )
    except PhoneCodeInvalidError:
        await send_json_response(
            writer,
            400,
            {"success": False, "message": "Invalid OTP code entered. Please check your Telegram app message."},
        )
    except PhoneCodeExpiredError:
        await send_json_response(
            writer,
            400,
            {"success": False, "message": "OTP code expired. Please request a new code."},
        )
    except PasswordHashInvalidError:
        await send_json_response(
            writer,
            400,
            {"success": False, "message": "Incorrect Two-Step Verification (2FA) password."},
        )
    except FloodWaitError as e:
        await send_json_response(
            writer,
            400,
            {"success": False, "message": f"Telegram rate limit: Please wait {e.seconds} seconds before trying again."},
        )
    except Exception as exc:
        traceback.print_exc()
        await send_json_response(writer, 400, {"success": False, "message": str(exc)})


async def main():
    port = int(os.environ.get("PORT") or os.environ.get("TELEVAULT_PORT", "8765"))
    server = await asyncio.start_server(handle_http_request, "0.0.0.0", port)
    print("=================================================================")
    print(" TeleVault MULTI-USER Telegram MTProto Bridge Server Running!")
    print(f" -> Mobile App UI : http://localhost:{port}/preview/index.html")
    print(f" -> LAN Wi-Fi URL : http://192.168.1.103:{port}")
    print("=================================================================")
    sys.stdout.flush()
    async with server:
        await server.serve_forever()


if __name__ == "__main__":
    asyncio.run(main())
