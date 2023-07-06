import HttpClient, {GetResponse} from '@cdo/apps/util/HttpClient';
import {ProjectRemixResponse, ProjectType} from '../types';

const rootUrl = '/projects/';

// Given a levelId and optionally a scriptId,
// get the project identifier (channel id) for that level (and script, if provided).
export async function getChannelForLevel(
  levelId: number,
  scriptId?: number
): Promise<Response> {
  let requestString = rootUrl;
  if (scriptId !== undefined) {
    requestString += `script/${scriptId}/`;
  }
  requestString += `level/${levelId}`;
  return fetch(requestString);
}

export async function remix(
  projectType: ProjectType,
  channelId: string
): Promise<GetResponse<ProjectRemixResponse>> {
  return HttpClient.fetchJson<ProjectRemixResponse>(
    `${rootUrl}${projectType}/${channelId}/lab2/remix`
  );
}
