import React from 'react';
import {mount, shallow} from 'enzyme';
import {expect} from '../../util/deprecatedChai';
import {UnconnectedCodeWorkspace as CodeWorkspace} from '../../../src/templates/CodeWorkspace';
import {singleton as studioAppSingleton} from '@cdo/apps/StudioApp';
import sinon from 'sinon';
import ShowCodeToggle from '@cdo/apps/templates/ShowCodeToggle';
import {workspaceAlertTypes} from '@cdo/apps/code-studio/projectRedux';

describe('CodeWorkspace', () => {
  const MINIMUM_PROPS = {
    editCode: true,
    isRtl: false,
    readonlyWorkspace: false,
    isRunning: false,
    showDebugger: false,
    pinWorkspaceToBottom: false,
    showProjectTemplateWorkspaceIcon: false,
    isMinecraft: false,
    runModeIndicators: false,
    showMakerToggle: false,
    workspaceAlert: {
      type: workspaceAlertTypes.error,
      message: 'This is an error message',
      displayBottom: false,
    },
    closeWorkspaceAlert: () => {},
  };

  let studioApp, workspace;

  beforeEach(() => {
    studioApp = studioAppSingleton();
    sinon.stub(studioApp, 'showGeneratedCode');
    workspace = mount(<CodeWorkspace {...MINIMUM_PROPS} />);
  });

  afterEach(() => {
    studioApp.showGeneratedCode.restore();
  });

  it('onToggleShowCode displays blocks for levels with enableShowBlockCount=true', () => {
    studioApp.enableShowBlockCount = true;

    workspace.find(ShowCodeToggle).simulate('click');
    let counter = workspace.find('#blockCounter');
    expect(counter).to.have.style('display', 'inline-block');
  });

  it('onToggleShowCode does not display blocks for levels with enableShowBlockCount=false', () => {
    studioApp.enableShowBlockCount = false;

    workspace.find(ShowCodeToggle).simulate('click');
    let counter = workspace.find('#blockCounter');
    expect(counter).to.have.style('display', 'none');
  });

  it('displays old version warning when displayOldVersionBanner is true', () => {
    const props = {
      ...MINIMUM_PROPS,
      ...{displayOldVersionBanner: true},
    };
    const wrapper = shallow(<CodeWorkspace {...props} />);
    expect(wrapper.find('div#oldVersionBanner')).to.have.lengthOf(1);
  });

  it('displays not started warning when displayNotStartedBanner is true', () => {
    const props = {
      ...MINIMUM_PROPS,
      ...{displayNotStartedBanner: true},
    };
    const wrapper = shallow(<CodeWorkspace {...props} />);
    expect(wrapper.find('div#notStartedBanner')).to.have.lengthOf(1);
  });

  it('displays a workspace alert when workspaceAlert exists', () => {
    expect(workspace.find('WorkspaceAlert')).to.have.lengthOf(1);
  });

  it('does not display a workspace alert when workspaceAlert is assigned null ', () => {
    const props = {
      ...MINIMUM_PROPS,
      ...{
        workspaceAlert: null,
      },
    };
    const wrapper = shallow(<CodeWorkspace {...props} />);
    expect(wrapper.find('WorkspaceAlert')).to.have.lengthOf(0);
  });

  it('displays a workspace alert at bottom of codeTextbox when editCode = true (implies Droplet)', () => {
    const props = {
      ...MINIMUM_PROPS,
      ...{
        editCode: true,
      },
    };
    const wrapper = shallow(<CodeWorkspace {...props} />);
    expect(wrapper.find('WorkspaceAlert')).to.have.lengthOf(1);
    expect(wrapper.find('ProtectedStatefulDiv#codeTextbox')).to.have.lengthOf(
      1
    );
  });

  it('displays a workspace alert at bottom of CodeWorkspace when editCode = false (implies Blockly)', () => {
    const props = {
      ...MINIMUM_PROPS,
      ...{
        editCode: false,
      },
    };
    const wrapper = shallow(<CodeWorkspace {...props} />);
    expect(wrapper.find('WorkspaceAlert')).to.have.lengthOf(1);
    expect(wrapper.find('ProtectedStatefulDiv#codeTextbox')).to.have.lengthOf(
      0
    );
  });
});
