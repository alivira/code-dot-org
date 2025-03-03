import React from 'react';
import msg from '@cdo/locale';

import ProtectedStatefulDiv from './ProtectedStatefulDiv';
import commonStyles from '../commonStyles';
import classNames from 'classnames';
import PropTypes from 'prop-types';
import Radium from 'radium'; // eslint-disable-line no-restricted-imports
import SkipButton from './SkipButton';
import {connect} from 'react-redux';

import blankImg from '../../static/common_images/1x1.gif';

export const FinishButton = () => (
  <button type="button" id="finishButton" className="share">
    <img src="/blockly/media/1x1.gif" />
    {msg.finish()}
  </button>
);

export const RunButton = Radium(props => (
  <button
    type="button"
    id="runButton"
    className={classNames(['launch', 'blocklyLaunch', props.hidden && 'hide'])}
    style={props.style}
  >
    <div>{props.runButtonText || msg.runProgram()}</div>
    <img src={blankImg} className="run26" alt="" />
  </button>
));
RunButton.propTypes = {
  hidden: PropTypes.bool,
  style: PropTypes.object,
  runButtonText: PropTypes.string,
};
RunButton.displayName = 'RunButton';

export const ResetButton = Radium(props => (
  <button
    type="button"
    id="resetButton"
    // See apps/style/common.scss for these class definitions
    className={classNames([
      'launch',
      'blocklyLaunch',
      props.hideText && 'hideText',
      props.hidden && 'hide',
    ])}
    style={[commonStyles.hidden, props.style]}
  >
    <div>{!props.hideText && msg.resetProgram()}</div>
    <img src={blankImg} className="reset26" alt="" />
  </button>
));
ResetButton.propTypes = {
  hidden: PropTypes.bool,
  style: PropTypes.object,
  hideText: PropTypes.bool,
};
ResetButton.displayName = 'ResetButton';

/**
 * A set of game buttons that consist of a run/reset button, and potentially a
 * set of children that we expect to be additional buttons.
 */
export const UnconnectedGameButtons = props => (
  <div>
    <ProtectedStatefulDiv id="gameButtons">
      {!props.noRunResetButton && (
        <>
          <RunButton
            hidden={props.hideRunButton}
            runButtonText={props.runButtonText}
          />
          <ResetButton hidden={props.hideResetButton} />
        </>
      )}
      {
        ' ' /* Explicitly insert whitespace so that this behaves like our ejs file*/
      }
      {props.children}
    </ProtectedStatefulDiv>
    <div id="gameButtonExtras">
      {props.showSkipButton && <SkipButton nextLevelUrl={props.nextLevelUrl} />}
      {props.showFinishButton && <FinishButton />}
    </div>
  </div>
);
UnconnectedGameButtons.propTypes = {
  hideRunButton: PropTypes.bool,
  hideResetButton: PropTypes.bool,
  runButtonText: PropTypes.string,
  playspacePhoneFrame: PropTypes.bool,
  nextLevelUrl: PropTypes.string,
  showSkipButton: PropTypes.bool,
  widgetMode: PropTypes.bool,
  showFinishButton: PropTypes.bool,
  children: PropTypes.node,
  noRunResetButton: PropTypes.bool,
};
UnconnectedGameButtons.displayName = 'GameButtons';

export default connect(state => ({
  hideRunButton: state.pageConstants.hideRunButton,
  hideResetButton: state.pageConstants.hideResetButton,
  runButtonText: state.pageConstants.runButtonText,
  playspacePhoneFrame: state.pageConstants.playspacePhoneFrame,
  nextLevelUrl: state.pageConstants.nextLevelUrl,
  showSkipButton: state.pageConstants.isChallengeLevel,
  widgetMode: state.pageConstants.widgetMode,
}))(UnconnectedGameButtons);
