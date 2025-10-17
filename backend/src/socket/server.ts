import http from 'http';
import { Server as IOServer, Socket } from 'socket.io';
import jwt from 'jsonwebtoken';

import { ENV } from '../config/env';

type RegistrationPayload = {
  managerId?: string | null;
  userKey?: string | null;
  teamIds?: Array<string | null | undefined> | string | null;
};

let io: IOServer | null = null;

const managerRoom = (managerId: string) => `manager:${managerId}`;
const userRoom = (userKey: string) => `user:${userKey}`;
const teamRoom = (teamId: string) => `team:${teamId}`;

export function initSocket(server: http.Server): IOServer {
  io = new IOServer(server, {
    cors: {
      origin: (origin, callback) => {
        if (!origin) return callback(null, true);
        const allowed = (ENV.allowedOrigins || '')
          .split(',')
          .map((s) => s.trim())
          .filter((s) => s.length > 0);
        if (allowed.includes(origin)) return callback(null, true);
        if (/^http:\/\/localhost(:\d+)?$/.test(origin)) return callback(null, true);
        if (/^https:\/\/[a-z0-9]+\.nexa-web\.pages\.dev$/.test(origin)) return callback(null, true);
        if (origin === 'https://app.nexapymesoft.com') return callback(null, true);
        return callback(new Error('Not allowed by CORS'));
      },
      credentials: true,
    },
  });

  io.on('connection', (socket) => {
    const authPayload = normalizeAuthPayload(socket.handshake.auth as RegistrationPayload & { token?: string } | undefined);
    registerFromPayload(socket, authPayload);

    socket.on('register', (payload: RegistrationPayload) => {
      registerFromPayload(socket, payload);
    });

    socket.on('joinTeams', (teamIds: Array<string | null | undefined> | string | null) => {
      normalizeTeamIds(teamIds).forEach((id) => socket.join(teamRoom(id)));
    });

    socket.on('leaveTeams', (teamIds: Array<string | null | undefined> | string | null) => {
      normalizeTeamIds(teamIds).forEach((id) => socket.leave(teamRoom(id)));
    });
  });

  return io;
}

function registerFromPayload(socket: Socket, payload?: RegistrationPayload) {
  if (!payload) return;
  const managerId = payload.managerId?.toString().trim();
  const userKey = payload.userKey?.toString().trim();
  const teamIds = normalizeTeamIds(payload.teamIds);

  if (managerId) {
    socket.join(managerRoom(managerId));
  }
  if (userKey) {
    socket.join(userRoom(userKey));
  }
  teamIds.forEach((id) => socket.join(teamRoom(id)));
}

export function getIO(): IOServer {
  if (!io) {
    throw new Error('Socket.io has not been initialised');
  }
  return io;
}

function normalizeAuthPayload(payload?: (RegistrationPayload & { token?: string | null })) {
  if (!payload) return {} as RegistrationPayload;
  const { token, ...rest } = payload;
  if (!token || typeof token !== 'string' || token.trim().length === 0) {
    return rest;
  }
  try {
    const decoded = jwt.verify(token, ENV.jwtSecret, {
      algorithms: ['HS256'],
    }) as Partial<{ provider: string; sub: string; managerId?: string }>;
    const inferred: RegistrationPayload = { ...rest };
    if (!inferred.userKey && decoded?.provider && decoded.sub) {
      inferred.userKey = `${decoded.provider}:${decoded.sub}`;
    }
    if (!inferred.managerId && decoded?.managerId) {
      inferred.managerId = decoded.managerId;
    }
    return inferred;
  } catch (err) {
    return rest;
  }
}

export function emitToManager(managerId: string, event: string, payload: unknown) {
  if (!io) return;
  io.to(managerRoom(managerId)).emit(event, payload);
}

export function emitToUser(userKey: string, event: string, payload: unknown) {
  if (!io) return;
  io.to(userRoom(userKey)).emit(event, payload);
}

export function emitToTeams(
  teamIds: Array<string | null | undefined> | string | null,
  event: string,
  payload: unknown
) {
  if (!io) return;
  const rooms = normalizeTeamIds(teamIds).map((id) => teamRoom(id));
  if (rooms.length === 0) return;
  io.to(rooms).emit(event, payload);
}

function normalizeTeamIds(input: Array<string | null | undefined> | string | null | undefined): string[] {
  if (input == null) return [];
  const list = Array.isArray(input) ? input : [input];
  return list
    .map((value) => {
      if (typeof value === 'string') {
        return value.trim();
      }
      if (value == null) {
        return '';
      }
      return value.toString().trim();
    })
    .filter((value) => value.length > 0);
}
