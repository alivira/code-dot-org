import React from 'react';
import Lab2Registry from '@cdo/apps/lab2/Lab2Registry';
import LegacyProjectRemix from './LegacyProjectRemix';
import {useAppDispatch} from '@cdo/apps/util/reduxHooks';
import ProjectRemixButton from './ProjectRemixButton';
import {remixProject} from '@cdo/apps/lab2/lab2Redux';
import {useSelector} from 'react-redux';
import {ProgressState} from '../../progressRedux';
import {currentLevel} from '../../progressReduxSelectors';
import {Level} from '@cdo/apps/types/progressTypes';

const ProjectRemix: React.FunctionComponent<ProjectRemixProps> = ({
  lightStyle,
}) => {
  const level = useSelector((state: {progress: ProgressState}) =>
    state.progress ? (currentLevel(state) as Level) : undefined
  );
  if (!level) {
    console.log('no level...');
    return null;
  } else if (level?.usesLab2) {
    console.log('about to call lab2projectremix');
    return <Lab2ProjectRemix lightStyle={lightStyle} />;
  } else {
    console.log('about to call legacyprojectremix');
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
