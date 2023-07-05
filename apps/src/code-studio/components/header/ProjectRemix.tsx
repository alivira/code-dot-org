import React from 'react';
import LabRegistry from '@cdo/apps/labs/LabRegistry';
import LegacyProjectRemix from './LegacyProjectRemix';

const ProjectRemix: React.FunctionComponent = () => {
  if (LabRegistry.getInstance().getProjectManager() !== null) {
    return <Lab2ProjectRemix />;
  } else {
    return <LegacyProjectRemix />;
  }
};

const Lab2ProjectRemix: React.FunctionComponent = () => {
  return <></>;
};

export default ProjectRemix;
