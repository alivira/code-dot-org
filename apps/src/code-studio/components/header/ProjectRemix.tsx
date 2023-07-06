import React from 'react';
import LabRegistry from '@cdo/apps/labs/LabRegistry';
import LegacyProjectRemix from './LegacyProjectRemix';
import {useAppDispatch} from '@cdo/apps/util/reduxHooks';
import ProjectRemixButton from './ProjectRemixButton';
import {remixProject} from '@cdo/apps/labs/labRedux';

const ProjectRemix: React.FunctionComponent<ProjectRemixProps> = ({
  lightStyle,
}) => {
  if (LabRegistry.getInstance().getProjectManager() !== null) {
    return <Lab2ProjectRemix lightStyle={lightStyle} />;
  } else {
    return <LegacyProjectRemix lightStyle={lightStyle} />;
  }
};

interface ProjectRemixProps {
  lightStyle: boolean;
}

const Lab2ProjectRemix: React.FunctionComponent<ProjectRemixProps> = ({
  lightStyle,
}) => {
  const dispatch = useAppDispatch();
  console.log('in Lab2ProjectRemix');

  return (
    <ProjectRemixButton
      lightStyle={lightStyle}
      inRestrictedShareMode={false}
      onRemix={() => dispatch(remixProject())}
    />
  );
};

export default ProjectRemix;
