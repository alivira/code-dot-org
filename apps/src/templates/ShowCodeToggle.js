import PropTypes from 'prop-types';
import React, {Component} from 'react';
import logToCloud from '../logToCloud';
import trackEvent from '../util/trackEvent';
import {singleton as studioApp} from '../StudioApp';
import {PaneButton} from './PaneHeader';
import msg from '@cdo/locale';
import UserPreferences from '../lib/util/UserPreferences';
import project from '../code-studio/initApp/project';

const BLOCKS_GLYPH_DARK =
  'data:image/gif;base64,R0lGODlhEAAQAIAAAE1XX01XXyH+GkNyZWF0ZWQgd2l0aCBHSU1QIG9uIGEgTWFjACH5BAEKAAEALAAAAAAQABAAAAIdjI+py40AowRp2molznBzB3LTIWpGGZEoda7gCxYAOw==';

const commonProps = {
  hasFocus: PropTypes.bool,
  isRtl: PropTypes.bool,
  isMinecraft: PropTypes.bool,
};

class ShowCodeButton extends Component {
  static propTypes = {
    ...commonProps,
    onClick: PropTypes.func,

    hidden: PropTypes.bool,
    showingBlocks: PropTypes.bool,
    showCodeLabel: PropTypes.string,
    showBlocksLabel: PropTypes.string,
  };

  static defaultProps = {
    showBlocksLabel: msg.showBlocksHeader(),
    showCodeLabel: msg.showCodeHeader(),
  };

  onClick() {
    trackEvent('showCode', 'click', 'header');
    this.props.onClick();
  }

  render() {
    const blockGlyphIconStyle = {
      ...styles.blocksGlyph,
      ...(this.props.isRtl && styles.blocksGlyphRtl),
    };
    const iconImageStyle = {
      ...styles.iconImage,
      ...(this.props.isRtl && styles.blocksGlyphImageRtl),
    };
    const blocksGlyphIcon = (
      <i style={blockGlyphIconStyle}>
        <img src={BLOCKS_GLYPH_DARK} style={iconImageStyle} alt="" />
      </i>
    );
    return (
      <PaneButton
        id="show-code-header"
        iconClass={this.props.showingBlocks ? 'fa fa-code' : ''}
        icon={this.props.showingBlocks ? null : blocksGlyphIcon}
        label={
          this.props.showingBlocks
            ? this.props.showCodeLabel
            : this.props.showBlocksLabel
        }
        isRtl={!!this.props.isRtl}
        isMinecraft={!!this.props.isMinecraft}
        headerHasFocus={!!this.props.hasFocus}
        onClick={this.onClick.bind(this)}
        style={
          this.props.hidden ? {display: 'none'} : {display: 'inline-block'}
        }
      />
    );
  }
}

class DropletCodeToggle extends Component {
  static propTypes = {
    ...commonProps,
    onToggle: PropTypes.func.isRequired,
  };

  afterInit = () => {
    this.forceUpdate();
  };

  UNSAFE_componentWillMount() {
    studioApp().on('afterInit', this.afterInit);
  }

  componentWillUnmount() {
    studioApp().removeListener('afterInit', this.afterInit);
  }

  toggle = () => {
    // are we trying to toggle from blocks to text (or the opposite)
    let fromBlocks = studioApp().currentlyUsingBlocks();

    let result;
    try {
      result = studioApp().editor.toggleBlocks();
    } catch (err) {
      result = {error: err, nonDropletError: true};
    }
    if (result && result.error) {
      logToCloud.addPageAction(logToCloud.PageAction.DropletTransitionError, {
        dropletError: !result.nonDropletError,
        fromBlocks,
      });
      studioApp().showToggleBlocksError();
    } else {
      studioApp().onDropletToggle();
      this.forceUpdate();
      this.props.onToggle(studioApp().currentlyUsingBlocks());
    }
  };

  onClick = () => {
    this.toggle();
    new UserPreferences().setUsingTextMode(
      !studioApp().currentlyUsingBlocks(),
      {
        project_id: project.getCurrentId(),
        level_id: studioApp().config.level.id,
      }
    );
  };

  render() {
    return (
      <ShowCodeButton
        hasFocus={this.props.hasFocus}
        isRtl={this.props.isRtl}
        isMinecraft={this.props.isMinecraft}
        onClick={this.onClick}
        hidden={!studioApp().enableShowCode}
        showingBlocks={studioApp().currentlyUsingBlocks()}
        showCodeLabel={msg.showTextHeader()}
      />
    );
  }
}

class BlocklyShowCodeButton extends Component {
  static propTypes = {
    ...commonProps,
    onToggle: PropTypes.func.isRequired,
  };

  onClick = () => {
    studioApp().showGeneratedCode();
    this.props.onToggle(true);
  };

  render() {
    return (
      <ShowCodeButton
        hasFocus={this.props.hasFocus}
        isRtl={this.props.isRtl}
        isMinecraft={this.props.isMinecraft}
        onClick={this.onClick}
        hidden={!studioApp().enableShowCode}
        showingBlocks
      />
    );
  }
}

export default class ShowCodeToggle extends Component {
  static propTypes = {
    ...commonProps,
    onToggle: PropTypes.func.isRequired,
  };

  afterInit = () => {
    this.forceUpdate();
  };

  UNSAFE_componentWillMount() {
    studioApp().on('afterInit', this.afterInit);
  }

  render() {
    return studioApp().editCode ? (
      <DropletCodeToggle {...this.props} />
    ) : (
      <BlocklyShowCodeButton {...this.props} />
    );
  }
}

const styles = {
  blocksGlyph: {
    lineHeight: '22px',
    paddingRight: 8,
    fontSize: 15,
    fontWeight: 'bold',
  },
  iconImage: {
    verticalAlign: 'text-bottom',
  },
  blocksGlyphRtl: {
    paddingRight: 0,
    paddingLeft: 8,
  },
  blocksGlyphImageRtl: {
    transform: 'scale(-1, 1)',
    MozTransform: 'scale(-1, 1)',
    WebkitTransform: 'scale(-1, 1)',
    OTransform: 'scale(-1, 1)',
    msTransform: 'scale(-1, 1)',
  },
};
