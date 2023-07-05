import React from 'react';
import {styles} from './EditableProjectName';
const i18n = require('@cdo/locale');

const ProjectRemixButton: React.FunctionComponent<ProjectRemixButtonProps> = ({
  lightStyle,
  inRestrictedShareMode,
  onRemix,
}) => {
  let className = 'project_remix header_button no-mc';
  if (lightStyle) {
    className += ' header_button_light';
  }
  return !inRestrictedShareMode ? (
    <button
      type="button"
      className={className}
      onClick={onRemix}
      style={styles.buttonSpacing}
    >
      {i18n.remix()}
    </button>
  ) : null;
};

interface ProjectRemixButtonProps {
  lightStyle: boolean;
  inRestrictedShareMode: boolean;
  onRemix: () => void;
}

export default ProjectRemixButton;
