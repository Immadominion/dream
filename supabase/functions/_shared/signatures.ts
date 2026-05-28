import nacl from 'npm:tweetnacl@1.0.3';
import bs58 from 'npm:bs58@6.0.0';

export function verifyWalletSignature(
  walletAddress: string,
  message: string,
  signatureBase64: string,
) {
  const publicKey = bs58.decode(walletAddress);
  const messageBytes = new TextEncoder().encode(message);
  const signature = Uint8Array.from(atob(signatureBase64), (char) =>
    char.charCodeAt(0),
  );

  return nacl.sign.detached.verify(messageBytes, signature, publicKey);
}