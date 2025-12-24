import { AccessToken } from "livekit-server-sdk";

export function issueLiveKitToken(params: {
  room: string;
  identity: string;
  name: string;
  isHost: boolean;
}) {
  const { LIVEKIT_API_KEY, LIVEKIT_API_SECRET } = process.env;
  if (!LIVEKIT_API_KEY || !LIVEKIT_API_SECRET) {
    throw new Error("LIVEKIT_API_KEY/LIVEKIT_API_SECRET is not set");
  }

  const at = new AccessToken(LIVEKIT_API_KEY, LIVEKIT_API_SECRET, {
    identity: params.identity,
    name: params.name,
  });

  at.addGrant({
    room: params.room,
    roomJoin: true,
    roomAdmin: params.isHost, // host can mute/remove etc. (client UI can expose later)
    canPublish: true,
    canSubscribe: true,
  });

  return at.toJwt();
}
