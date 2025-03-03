import React from 'react';
import Button from '@cdo/apps/templates/Button';
import {Mode} from './DanceAiModal';

interface ModalButtonProps extends React.ComponentProps<typeof Button> {
  currentMode: Mode;
  showFor?: Mode[];
  hideFor?: Mode[];
  enableFor?: Mode[];
  disableFor?: Mode[];
}

const ModalButton: React.FunctionComponent<ModalButtonProps> = props => {
  const {currentMode, showFor, hideFor, enableFor, disableFor} = props;

  if (
    (showFor && !showFor.includes(currentMode)) ||
    (hideFor && hideFor.includes(currentMode))
  ) {
    return null;
  }

  return (
    <Button
      disabled={
        (enableFor && !enableFor.includes(currentMode)) ||
        (disableFor && disableFor.includes(currentMode))
      }
      {...props}
    />
  );
};

export default ModalButton;
