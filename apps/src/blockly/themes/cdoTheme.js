import GoogleBlockly from 'blockly/core';
import fontConstants from '@cdo/apps/fontConstants';
import {Themes} from '../constants.js';
import cdoBlockStyles from './cdoBlockStyles.mjs';

export default GoogleBlockly.Theme.defineTheme(Themes.MODERN, {
  base: GoogleBlockly.Themes.Classic,
  blockStyles: cdoBlockStyles,
  categoryStyles: {},
  componentStyles: {
    toolboxBackgroundColour: '#DDDDDD',
  },
  fontStyle: {
    family: fontConstants['main-font'],
    weight: fontConstants['regular-font-weight'],
  },
  startHats: null,
});
