import sinon from 'sinon';
import {expect} from '../../util/reconfiguredChai';
import {parseElement} from '@cdo/apps/xml';
import {Position} from '@cdo/apps/constants';
import {singleton as studioAppSingleton} from '@cdo/apps/StudioApp';
import {DEFAULT_EXECUTION_INFO} from '@cdo/apps/lib/tools/jsinterpreter/CustomMarshalingInterpreter';
import Artist from '@cdo/apps/turtle/artist';
import {stubRedux, restoreRedux, registerReducers} from '@cdo/apps/redux';
import pageConstants from '@cdo/apps/redux/pageConstants';

const SHORT_DIAGONAL = 50 * Math.sqrt(2);
const VERY_LONG_DIAGONAL = 150 * Math.sqrt(2);

describe('Artist', () => {
  beforeEach(() => {
    stubRedux();
    registerReducers({pageConstants});
  });

  afterEach(() => {
    restoreRedux();
  });

  describe('drawing with joints', () => {
    var joints, segments, artist;
    beforeEach(() => {
      artist = new Artist();
      artist.visualization = new Artist.Visualization();
      joints = 0;
      segments = [];
      artist.visualization.drawJointAtTurtle_ = () => {
        joints += 1;
      };
      artist.visualization.drawForwardLine_ = dist => {
        segments.push(dist);
      };
    });
    it('draws 2 joints on a short segment', () => {
      artist.visualization.drawForwardWithJoints_(50, false);

      expect(joints).to.equal(2);
      expect(segments).to.eql([50]);
    });
    it('draws 3 joints on a long segment', () => {
      artist.visualization.drawForwardWithJoints_(100, false);

      expect(joints).to.equal(3);
      expect(segments).to.eql([50, 50]);
    });
    it('draws no joints on a very short segment', () => {
      artist.visualization.drawForwardWithJoints_(10, false);

      expect(joints).to.equal(0);
      expect(segments).to.eql([10]);
    });
    it('draws 2 joints on a short diagonal segment', () => {
      artist.visualization.drawForwardWithJoints_(SHORT_DIAGONAL, true);

      expect(joints).to.equal(2);
      expect(segments).to.eql([SHORT_DIAGONAL]);
    });
    it('draws 4 joints on a very long diagonal segment', () => {
      artist.visualization.drawForwardWithJoints_(VERY_LONG_DIAGONAL, true);

      expect(joints).to.equal(4);
      expect(segments).to.eql([SHORT_DIAGONAL, SHORT_DIAGONAL, SHORT_DIAGONAL]);
    });
    it('draws no joints on a very short diagonal segment', () => {
      artist.visualization.drawForwardWithJoints_(SHORT_DIAGONAL - 1, true);

      expect(joints).to.equal(0);
      expect(segments).to.eql([SHORT_DIAGONAL - 1]);
    });
  });

  describe('drawing with patterns', () => {
    it('draws a pattern backwards', () => {
      let artist = new Artist();
      let width = 100;
      let height = 100;
      let img = new Image(width, height);

      artist.visualization = new Artist.Visualization();
      artist.visualization.currentPathPattern = img;
      const setDrawPatternBackwardSpy = sinon.spy(
        artist.visualization.ctxScratch,
        'drawImage'
      );
      artist.visualization.drawForwardLineWithPattern_(-100);

      expect(setDrawPatternBackwardSpy).to.be.have.been.calledWith(
        img,
        100,
        0,
        -100,
        100,
        -25,
        -50,
        -50,
        100
      );

      setDrawPatternBackwardSpy.restore();
    });

    it('draws a pattern forward', () => {
      let artist = new Artist();
      let width = 100;
      let height = 100;
      let img = new Image(width, height);

      artist.visualization = new Artist.Visualization();
      artist.visualization.currentPathPattern = img;
      const setDrawPatternForwardSpy = sinon.spy(
        artist.visualization.ctxScratch,
        'drawImage'
      );
      artist.visualization.drawForwardLineWithPattern_(100);

      expect(setDrawPatternForwardSpy).to.be.have.been.calledWith(
        img,
        0,
        0,
        100,
        100,
        -25,
        -50,
        150,
        100
      );

      setDrawPatternForwardSpy.restore();
    });
  });

  describe('Accepts a third argument parameter', () => {
    it('draws a sticker when size is null', () => {
      let artist = new Artist();
      const img = new Image(100, 100);
      let size = null;
      let blockId = 'block_id_4';
      let options = {smoothAnimate: false};

      artist.visualization = new Artist.Visualization();
      const setStickerSize = sinon.spy(
        artist.visualization.ctxScratch,
        'drawImage'
      );
      artist.stickers = {Alien: img};
      artist.step('sticker', ['Alien', size, blockId], options);

      expect(setStickerSize).to.be.have.been.calledWith(
        img,
        0,
        0,
        100,
        100,
        -50,
        -100,
        100,
        100
      );

      setStickerSize.restore();
    });
    it('draws a sticker when size is 0', () => {
      let artist = new Artist();
      const img = new Image(100, 100);
      let size = 0;
      let blockId = 'block_id_4';
      let options = {smoothAnimate: false};

      artist.visualization = new Artist.Visualization();
      const setStickerSize = sinon.spy(
        artist.visualization.ctxScratch,
        'drawImage'
      );
      artist.stickers = {Alien: img};
      artist.step('sticker', ['Alien', size, blockId], options);

      expect(setStickerSize).to.be.have.been.calledWith(
        img,
        0,
        0,
        100,
        100,
        -0,
        -0,
        0,
        0
      );

      setStickerSize.restore();
    });
    it('draws a sticker when size is 50 px', () => {
      let artist = new Artist();
      const img = new Image(100, 100);
      let size = 50;
      let blockId = 'block_id_4';
      let options = {smoothAnimate: false};

      artist.visualization = new Artist.Visualization();
      const setStickerSize = sinon.spy(
        artist.visualization.ctxScratch,
        'drawImage'
      );
      artist.stickers = {Alien: img};
      artist.step('sticker', ['Alien', size, blockId], options);

      expect(setStickerSize).to.be.have.been.calledWith(
        img,
        0,
        0,
        100,
        100,
        -25,
        -50,
        50,
        50
      );

      setStickerSize.restore();
    });
    it('draws a sticker when size is 200 px', () => {
      // Test condition when width < size && height < size
      let artist = new Artist();
      const img = new Image(100, 100);
      let size = 200;
      let blockId = 'block_id_4';
      let options = {smoothAnimate: false};

      artist.visualization = new Artist.Visualization();
      const setStickerSize = sinon.spy(
        artist.visualization.ctxScratch,
        'drawImage'
      );
      artist.stickers = {Alien: img};
      artist.step('sticker', ['Alien', size, blockId], options);

      expect(setStickerSize).to.be.have.been.calledWith(
        img,
        0,
        0,
        100,
        100,
        -50,
        -100,
        100,
        100
      );

      setStickerSize.restore();
    });
    it('draws a sticker when size is 30 px', () => {
      let artist = new Artist();
      // Test condition when width > height
      const img = new Image(100, 40);
      let size = 30;
      let blockId = 'block_id_4';
      let options = {smoothAnimate: false};

      artist.visualization = new Artist.Visualization();
      const setStickerSize = sinon.spy(
        artist.visualization.ctxScratch,
        'drawImage'
      );
      artist.stickers = {Alien: img};
      artist.step('sticker', ['Alien', size, blockId], options);

      expect(setStickerSize).to.be.have.been.calledWith(
        img,
        0,
        0,
        100,
        40,
        -15,
        -12,
        30,
        12
      );

      setStickerSize.restore();
    });
  });

  describe('pointTo', () => {
    let artist;
    beforeEach(() => {
      artist = new Artist();
      artist.visualization = new Artist.Visualization();
    });

    it('can point to a specific direction', () => {
      const absoluteDirection = [0, 30, 45, 60, 180, 270];
      const blockId = 'block_id_4';
      const pointToSpy = sinon.spy(artist.visualization, 'pointTo');

      absoluteDirection.forEach(angle => {
        artist.step('PT', [angle, blockId]);
        expect(pointToSpy).to.be.have.been.calledWith(angle);
      });
      pointToSpy.restore();
    });

    it('can point to a 50 degrees', () => {
      let angle = 50;
      let blockId = 'block_id_5';

      artist.visualization.angle = 50;
      artist.step('PT', [angle, blockId]);

      expect(artist.visualization.angle).to.equal(angle);
    });

    it('should call setHeading', () => {
      let angle = 60;
      let blockId = 'block_id_8';

      const setHeadingStub = sinon.stub(artist.visualization, 'setHeading');
      artist.step('PT', [angle, blockId]);

      expect(setHeadingStub).to.be.have.been.calledOnce;

      setHeadingStub.restore();
    });
  });

  describe('jumpTo', () => {
    let artist;
    beforeEach(() => {
      artist = new Artist();
      artist.visualization = new Artist.Visualization();
    });

    it('can jump to coordinates', () => {
      const coords = [0, 10, 20, 30, 40, 50, 60, 70, 80, 90];

      coords.forEach(x => {
        coords.forEach(y => {
          artist.step('JT', [[x, y]]);
          expect(artist.visualization.x).to.equal(x);
          expect(artist.visualization.y).to.equal(y);
        });
      });
    });

    it('can jump to a position', () => {
      const expectations = {
        TOPLEFT: [0, 0],
        TOPCENTER: [200, 0],
        TOPRIGHT: [400, 0],
        MIDDLELEFT: [0, 200],
        MIDDLECENTER: [200, 200],
        MIDDLERIGHT: [400, 200],
        BOTTOMLEFT: [0, 400],
        BOTTOMCENTER: [200, 400],
        BOTTOMRIGHT: [400, 400],
      };

      Object.keys(expectations).forEach(position => {
        const [x, y] = expectations[position];
        artist.step('JT', [Position[position]]);
        expect(artist.visualization.x).to.equal(x);
        expect(artist.visualization.y).to.equal(y);
      });
    });
  });

  describe('autoArtist', () => {
    const studioApp = studioAppSingleton();

    it('executes upon reset', done => {
      const artist = new Artist();
      const execute = sinon.stub(artist, 'execute');
      artist.injectStudioApp(studioApp);
      artist
        .init({
          skin: {},
          level: {
            autoRun: true,
          },
        })
        .then(done)
        .catch(() => done());

      artist.resetButtonClick();

      expect(execute).to.have.been.called;
      execute.restore();
    });

    it('executes upon code changes', done => {
      const artist = new Artist();
      const execute = sinon.stub(Artist.prototype, 'execute');
      const container = document.createElement('div');
      container.id = 'artistContainer';
      document.body.appendChild(container);
      artist.injectStudioApp(studioApp);
      artist
        .init({
          skin: {},
          level: {
            autoRun: true,
          },
          containerId: 'artistContainer',
        })
        .then(done)
        .catch(() => done());
      studioApp.runChangeHandlers();

      expect(execute).to.have.been.called;
      execute.restore();
    });
  });

  describe('prepareForRemix', () => {
    let artist, newDom, oldXml;

    beforeEach(() => {
      artist = new Artist();
      artist.skin = {id: 'artist'};

      oldXml = `
        <block type="when_run">
          <next>
            <block type="draw_move" inline="true">
              <value name="VALUE">
                <block type="math_nubmer">
                  <title name="NUM">40</title>
                </block>
              </value>
            </block>
          </next>
        </block>`;
      newDom = undefined;
      window.Blockly = {
        Xml: {
          blockSpaceToDom() {
            return parseElement(oldXml);
          },
          domToText(dom) {
            return new XMLSerializer().serializeToString(dom);
          },
        },
        mainBlockSpace: {
          clear() {},
        },
        cdoUtils: {
          loadBlocksToWorkspace(blockspace, str) {
            newDom = parseElement(str);
          },
        },
      };
    });

    it('does nothing if the level specifies no start position or direction', () => {
      artist.level = {};
      artist.prepareForRemix();

      // loadBlocksToWorkspace should not have been called
      expect(newDom).to.be.undefined;
    });

    it('adds moveTo block if initialX is set', () => {
      artist.level = {
        initialX: 30,
      };
      artist.prepareForRemix();

      expect(
        newDom.querySelector('block[type="jump_to_xy"] title[name="XPOS"]')
          .firstChild.wholeText
      ).to.equal('30');
    });

    it('adds moveTo block if initialX and initialY are set', () => {
      artist.level = {
        initialX: 30,
        initialY: 50,
      };
      artist.prepareForRemix();

      expect(
        newDom.querySelector('block[type="jump_to_xy"] title[name="XPOS"]')
          .firstChild.wholeText
      ).to.equal('30');
      expect(
        newDom.querySelector('block[type="jump_to_xy"] title[name="YPOS"]')
          .firstChild.wholeText
      ).to.equal('50');
    });

    it('adds a moveTo block with 200 for the y coordinate if initialY is not specified in the level', () => {
      artist.level = {
        initialX: 30,
      };
      artist.prepareForRemix();

      expect(
        newDom.querySelector('block[type="jump_to_xy"] title[name="YPOS"]')
          .firstChild.wholeText
      ).to.equal('200');
    });

    it('adds moveTo and turn blocks if initialX and startDirection are set', () => {
      artist.level = {
        initialX: 30,
        startDirection: 45,
      };
      artist.prepareForRemix();

      expect(
        newDom.querySelector('block[type="jump_to_xy"] title[name="XPOS"]')
          .firstChild.wholeText
      ).to.equal('30');
      expect(
        newDom.querySelector('block[type="draw_turn"] title[name="NUM"]')
          .firstChild.wholeText
      ).to.equal('-45');
    });

    it('adds a whenRun block if none is present', () => {
      artist.level = {
        initialX: 30,
      };
      oldXml = '';

      artist.prepareForRemix();

      expect(newDom.querySelector('block[type="when_run"]')).not.to.be
        .undefined;
    });
  });

  it('Does not alert for infinite loops', () => {
    const artist = new Artist();
    const alertStub = sinon.stub(window, 'alert');

    artist.evalCode('while(true) executionInfo.checkTimeout();', {
      ...DEFAULT_EXECUTION_INFO,
      ticks: 10, // Declare an infinite loop after 10 ticks
    });

    expect(alertStub).to.not.have.been.called;

    alertStub.restore();
  });
});
