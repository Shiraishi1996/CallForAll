import RoomClient from "./roomClient";

export default function Page({ params }: { params: { roomId: string } }) {
  return <RoomClient roomId={params.roomId} />;
}
