var chalk = require('chalk');
var child_process = require('child_process');
var path = require('path');
var fs = require('fs');
var _ = require('lodash');
var sass = require('sass');

var envConstants = require('./envConstants');
var checkEntryPoints = require('./script/checkEntryPoints');

const {ALL_APPS, appsEntriesFor} = require('./webpackEntryPoints');
const {createWebpackConfig} = require('./webpack.config');
const offlineWebpackConfig = require('./webpackOffline.config');
const {VALID_KARMA_CLI_FLAGS} = require('./karma.conf');

// Review every couple of years to see if an increase improves test performance
const MEM_PER_KARMA_PROCESS_MB = 4300;

module.exports = function (grunt) {
  var config = {};

  /**
   * Interval for filesystem polling in watch mode.
   * Warning: 100ms hits 75% CPU on OS X. 700ms is around 10%.
   * See https://github.com/gruntjs/grunt-contrib-watch/issues/145
   * If OS X polling remains a CPU issue, can try grunt-este-watch
   * @const {number}
   */
  var DEV_WATCH_INTERVAL = parseInt(grunt.option('delay')) || 700;

  /** @const {string} */
  var SINGLE_APP = grunt.option('app') || envConstants.APP;
  var appsToBuild = SINGLE_APP ? [SINGLE_APP] : ALL_APPS;

  var ace_suffix = envConstants.DEV ? '' : '-min';
  var piskelRootStdout = child_process.execSync('npx piskel-root');
  var piskelRoot = String(piskelRootStdout).replace(/\s+$/g, '');
  var PISKEL_DEVELOPMENT_MODE = grunt.option('piskel-dev');
  if (PISKEL_DEVELOPMENT_MODE) {
    var localNodeModulesRoot = String(
      child_process.execSync('npm prefix')
    ).replace(/\s+$/g, '');
    if (piskelRoot.indexOf(localNodeModulesRoot) === -1) {
      // Piskel has been linked to a local development repo, we're good to go.
      piskelRoot = path.resolve(piskelRoot, '..', 'dev');
      console.log(chalk.bold.yellow('-- PISKEL DEVELOPMENT MODE --'));
      console.log(
        chalk.yellow('Make sure you have a local development build of piskel')
      );
      console.log(chalk.yellow('Inlining PISKEL_DEVELOPMENT_MODE=true'));
      console.log(
        chalk.yellow(
          'Copying development build of Piskel instead of release build'
        )
      );
    } else {
      console.log(chalk.bold.red('Unable to enable Piskel development mode.'));
      console.log(
        chalk.red(
          'In order to use Piskel development mode, your apps ' +
            'package must be linked to a local development copy of the Piskel ' +
            'repository with a complete dev build.' +
            '\n' +
            '\n  1. git clone https://github.com/code-dot-org/piskel.git <new-directory>' +
            '\n  2. cd <new-directory>' +
            '\n  3. npm install && grunt build-dev' +
            '\n  4. npm link' +
            '\n  5. cd <code-dot-org apps directory>' +
            '\n  6. npm link @code-dot-org/piskel' +
            '\n  7. rerun your previous command' +
            '\n'
        )
      );
      process.exitCode = 1; // Failure!
      return;
    }
  }

  config.copy = {
    src: {
      files: [
        {
          expand: true,
          cwd: 'src/',
          src: ['**/*.js', '**/*.jsx'],
          dest: 'build/js',
        },
      ],
    },
    static: {
      files: [
        {
          expand: true,
          cwd: 'static/',
          src: ['**'],
          dest: 'build/package/media',
        },
        {
          expand: true,
          cwd: 'lib/blockly/media',
          src: ['**'],
          //TODO: Would be preferrable to separate Blockly media.
          dest: 'build/package/media',
        },
        {
          expand: true,
          cwd: 'node_modules/blockly/media',
          src: ['**'],
          dest: 'build/package/media/google_blockly',
        },
        {
          expand: true,
          cwd: 'node_modules/@code-dot-org/craft/dist/assets',
          src: ['**'],
          dest: 'build/package/media/skins/craft',
        },
        {
          expand: true,
          cwd: 'node_modules/@code-dot-org/ml-activities/dist/assets',
          src: ['**'],
          dest: 'build/package/media/skins/fish',
        },
        {
          expand: true,
          cwd: 'node_modules/@code-dot-org/ml-playground/dist/assets',
          src: ['**'],
          dest: 'build/package/media/skins/ailab',
        },

        // We have to do some weird stuff to get our fallback video player working.
        // video.js expects some of its own files to be served by the application, so
        // we include them in our build and access them via static (non-fingerprinted)
        // root-relative paths.
        // We may have to do something similar with ace editor later, but generally
        // we'd prefer to avoid this way of doing things.
        // TODO: At some point, we may want to better rationalize the package
        // structure for all of our different assets (including vendor assets,
        // blockly media, etc).
        {
          expand: true,
          cwd: './node_modules/video.js/dist',
          src: ['**'],
          dest: 'build/package/video-js',
        },
      ],
    },
    lib: {
      files: [
        {
          expand: true,
          cwd: 'lib/blockly',
          src: ['*_*.js'],
          dest: 'build/locales',
          // e.g., ar_sa.js -> ar_sa/blockly_locale.js
          rename: function (dest, src) {
            var outputPath = src.replace(
              /(.+_.+)\.js/g,
              '$1/blockly_locale.js'
            );
            return path.join(dest, outputPath);
          },
        },
        // minifying ace code requires some advanced configuration:
        // https://github.com/ajaxorg/ace/blob/b808ac14ec6d6afa74b36ff5c03452a2832b32a4/Makefile.dryice.js#L620-L638
        // instead of replicating that configuration here, we keep minified
        // and unminified js in our repo and provide the correct one
        // based on whether we are in development or production mode.
        {
          expand: true,
          cwd: 'lib/ace/src' + ace_suffix + '-noconflict/',
          src: ['**/*.js'],
          dest: 'build/package/js/ace/',
        },
        // Pull p5.js and p5.play.js into the package from our forks. These are
        // needed by the gamelab exporter code in production and development.
        {
          expand: true,
          cwd: './node_modules/@code-dot-org/p5/lib',
          src: ['p5.js'],
          dest: 'build/package/js/p5play/',
        },
        {
          expand: true,
          cwd: './node_modules/@code-dot-org/p5.play/lib',
          src: ['p5.play.js'],
          dest: 'build/package/js/p5play/',
        },
        // Piskel must not be minified or digested in order to work properly.
        {
          expand: true,
          // For some reason, if we provide piskel root as an absolute path here,
          // our dest ends up with an empty set of directories matching the path
          // If we provide it as a relative path, that does not happen
          cwd: './' + path.relative(process.cwd(), piskelRoot),
          src: ['**'],
          dest: 'build/package/js/piskel/',
        },
        {
          expand: true,
          cwd: 'lib/droplet',
          src: ['droplet-full*.js'],
          dest: 'build/minifiable-lib/droplet/',
        },
        {
          expand: true,
          cwd: 'lib/droplet',
          src: ['droplet.min.css'],
          dest: 'build/package/css/droplet/',
        },
        {
          expand: true,
          cwd: 'lib/tooltipster',
          src: ['*.js'],
          dest: 'build/minifiable-lib/tooltipster/',
        },
        {
          expand: true,
          cwd: 'lib/phaser',
          src: ['*.js'],
          dest: 'build/minifiable-lib/phaser/',
        },
        {
          expand: true,
          cwd: 'lib/tooltipster',
          src: ['tooltipster.min.css'],
          dest: 'build/package/css/tooltipster/',
        },
        {
          expand: true,
          cwd: 'lib/fileupload',
          src: ['*.js'],
          dest: 'build/minifiable-lib/fileupload/',
        },
      ],
    },
    unhash: {
      files: [
        {
          expand: true,
          cwd: 'build/package/js',
          // The applab and gamelab exporters need unhashed copies of these files.
          src: [
            'webpack-runtimewp*.js',
            'webpack-runtimewp*.min.js',
            'applab-apiwp*.js',
            'applab-apiwp*.min.js',
            'gamelab-apiwp*.js',
            'gamelab-apiwp*.min.js',
          ],
          dest: 'build/package/js',
          // e.g. webpack-runtimewp0123456789aabbccddee.min.js --> webpack-runtime.min.js
          rename: function (dest, src) {
            var outputFile = src.replace(/wp[0-9a-f]{20}/, '');
            return path.join(dest, outputFile);
          },
        },
      ],
    },
  };

  config.sass = {
    all: {
      options: {
        // Compression currently occurs at the ../dashboard sprockets layer.
        // dart-sass: Only the "expanded" and "compressed" values of outputStyle are supported.
        outputStyle: 'expanded',
        includePaths: ['node_modules', '../shared/css/'],
        implementation: sass,
        quietDeps: true,
      },
      files: _.fromPairs(
        [
          ['build/package/css/common.css', 'style/common.scss'],
          [
            'build/package/css/code-studio.css',
            'style/code-studio/code-studio.scss',
          ],
          [
            'build/package/css/certificates.css',
            'style/curriculum/certificates.scss',
          ],
          ['build/package/css/courses.css', 'style/curriculum/courses.scss'],
          ['build/package/css/scripts.css', 'style/curriculum/scripts.scss'],
          ['build/package/css/lessons.css', 'style/curriculum/lessons.scss'],
          ['build/package/css/markdown.css', 'style/curriculum/markdown.scss'],
          ['build/package/css/levels.css', 'style/curriculum/levels.scss'],
          ['build/package/css/rollups.css', 'style/curriculum/rollups.scss'],
          [
            'build/package/css/curriculum_table_styling.css',
            'style/curriculum/curriculum_table_styling.scss',
          ],
          [
            'build/package/css/curriculum_navigation.css',
            'style/curriculum/navigation.scss',
          ],
          [
            'build/package/css/levelbuilder.css',
            'style/code-studio/levelbuilder.scss',
          ],
          [
            'build/package/css/leveltype_widget.css',
            'style/code-studio/leveltype_widget.scss',
          ],
          ['build/package/css/plc.css', 'style/code-studio/plc.scss'],
          ['build/package/css/pd.css', 'style/code-studio/pd.scss'],
          ['build/package/css/petition.css', 'style/code-studio/petition.scss'],
          [
            'build/package/css/publicKeyCryptography.css',
            'style/publicKeyCryptography/publicKeyCryptography.scss',
          ],
          [
            'build/package/css/foorm_editor.css',
            'style/code-studio/foorm_editor.scss',
          ],
        ].concat(
          appsToBuild.map(function (app) {
            return [
              'build/package/css/' + app + '.css', // dst
              'style/' + app + '/style.scss', // src
            ];
          })
        )
      ),
    },
  };

  // Takes a key-value .json file and runs it through MessageFormat to create a localized .js file.
  config.messages = {
    all: {
      options: {
        dest: 'build/locales',
      },
      files: [
        {
          // e.g., build/js/i18n/bounce/ar_sa.json -> build/package/js/ar_sa/bounce_locale.js
          rename: function (dest, src) {
            var outputPath = src.replace(
              /(build\/)?i18n\/(\w*)\/(\w+_\w+).json/g,
              '$3/$2_locale.js'
            );
            return path.join(dest, outputPath);
          },
          expand: true,
          src: ['i18n/**/*.json'],
          dest: 'build/locales',
        },
      ],
    },
  };

  config.ejs = {
    all: {
      srcBase: 'src',
      destBase: 'build/js',
    },
  };

  config.exec = {
    convertScssVars: './script/convert-scss-variables.js',
    generateSharedConstants: 'bundle exec ./script/generateSharedConstants.rb',
  };

  grunt.registerTask('karma', ['preconcatForKarma', 'karma start']);
  grunt.registerTask('karma start', () => {
    // Forward select grunt command-line flags to `karma start`
    const KARMA_CLI_FLAGS = VALID_KARMA_CLI_FLAGS.flatMap(arg =>
      grunt.option(arg) ? [`--${arg}`, grunt.option(arg)] : []
    );

    console.log(chalk.green(`>> npx karma start ${KARMA_CLI_FLAGS.join(' ')}`));
    child_process.spawnSync('npx', ['karma', 'start', ...KARMA_CLI_FLAGS], {
      stdio: 'inherit',
      env: {
        ...process.env,
        NODE_OPTIONS: `--max-old-space-size=${MEM_PER_KARMA_PROCESS_MB}`,
      },
    });
  });

  grunt.registerTask('preconcatForKarma', [
    'newer:messages',
    'exec:convertScssVars',
    'exec:generateSharedConstants',
    'newer:copy:static',
  ]);

  config.clean = {
    build: ['build'],
    karma: {
      options: {force: true},
      src: ['build/karma'],
    },
  };

  const piskelDevMode = PISKEL_DEVELOPMENT_MODE;

  // Create a webpack entry point for each of the apps in `appsToBuild`.
  // See `ALL_APPS` in webpackEntryPoints.js for a list of valid apps, e.g.
  // gamelab, maze, etc.
  var appsEntries = appsEntriesFor(appsToBuild);

  config.webpack = {
    build: createWebpackConfig({
      appsEntries,
      minify: false,
      watch: false,
      piskelDevMode,
    }),

    buildOffline: offlineWebpackConfig,

    uglify: createWebpackConfig({
      appsEntries,
      minify: true,
      watch: false,
      piskelDevMode,
    }),

    watch: createWebpackConfig({
      appsEntries,
      minify: false,
      watch: true,
      watchNotify: grunt.option('watch-notify'),
      piskelDevMode,
    }),
  };

  config['webpack-dev-server'] = {
    watch: {
      webpack: createWebpackConfig({
        appsEntries,
        minify: false,
        watch: false,
        piskelDevMode,
      }),
      keepAlive: true,
      proxy: {
        '**': 'http://localhost:3000',
      },
      publicPath: '/assets/js/',
      hot: true,
      inline: true,
      port: 3001,
      host: '0.0.0.0',
      watchOptions: {
        aggregateTimeout: 1000,
        poll: 1000,
        ignored: /^node_modules\/[^@].*/,
      },
    },
  };

  config.uglify = {
    lib: {
      files: _.fromPairs(
        ['p5play/p5.play.js', 'p5play/p5.js'].map(function (src) {
          return [
            'build/package/js/' + src.replace(/\.js$/, '.min.js'), // dst
            'build/package/js/' + src, // src
          ];
        })
      ),
    },
  };

  config.watch = {
    // JS files watched by webpack
    style: {
      files: ['style/**/*.scss', 'style/**/*.sass'],
      tasks: ['newer:sass', 'notify:sass'],
      options: {
        interval: DEV_WATCH_INTERVAL,
        livereload: envConstants.AUTO_RELOAD,
        interrupt: true,
      },
    },
    content: {
      files: ['static/**/*'],
      tasks: ['newer:copy', 'notify:content'],
      options: {
        interval: DEV_WATCH_INTERVAL,
        livereload: envConstants.AUTO_RELOAD,
      },
    },
    vendor_js: {
      files: ['lib/**/*.js'],
      tasks: ['newer:copy:lib', 'notify:vendor_js'],
      options: {
        interval: DEV_WATCH_INTERVAL,
        livereload: envConstants.AUTO_RELOAD,
      },
    },
    messages: {
      files: ['i18n/**/*.json'],
      tasks: ['messages', 'notify:messages'],
      options: {
        interval: DEV_WATCH_INTERVAL,
        livereload: envConstants.AUTO_RELOAD,
      },
    },
  };

  (config.concurrent = {
    // run our two watch tasks concurrently so that they dont block each other
    watch: {
      tasks: [
        'watch',
        envConstants.HOT ? 'webpack-dev-server:watch' : 'webpack:watch',
      ],
      options: {
        logConcurrentOutput: true,
      },
    },
  }),
    (config.notify = {
      'js-build': {options: {message: 'JS build completed.'}},
      sass: {options: {message: 'SASS build completed.'}},
      content: {options: {message: 'Content build completed.'}},
      ejs: {options: {message: 'EJS build completed.'}},
      messages: {options: {message: 'i18n messages build completed.'}},
      vendor_js: {options: {message: 'vendor JS copy done.'}},
    });

  grunt.initConfig(config);

  // Autoload grunt tasks
  require('load-grunt-tasks')(grunt, {
    pattern: ['grunt-*', '!grunt-lib-contrib'],
  });

  grunt.loadTasks('tasks');
  grunt.registerTask('noop', function () {});

  // Generate locale stub files in the build/locale/current folder
  grunt.registerTask('locales', function () {
    var current = path.resolve('build/locale/current');
    child_process.execSync('mkdir -p ' + current);
    appsToBuild
      .concat(
        'common',
        'tutorialExplorer',
        'regionalPartnerSearch',
        'regionalPartnerMiniContact'
      )
      .map(function (item) {
        var localeType = item === 'common' ? 'locale' : 'appLocale';
        var localeString =
          '/*' +
          item +
          '*/ ' +
          'module.exports = window.locales.' +
          localeType +
          ';';
        fs.writeFileSync(path.join(current, item + '.js'), localeString);
      });
  });

  // Checks the size of Droplet to ensure it's built with LANGUAGE=javascript
  grunt.registerTask('checkDropletSize', function () {
    var bytes = fs.statSync('lib/droplet/droplet-full.min.js').size;
    if (bytes > 500 * 1000) {
      grunt.warn(
        '"droplet-full.min.js" is larger than 500kb. Did you build with LANGUAGE=javascript?'
      );
    }
  });

  grunt.registerTask('prebuild', [
    'checkDropletSize',
    'lint-entry-points',
    'newer:messages',
    'exec:convertScssVars',
    'exec:generateSharedConstants',
    'newer:copy:src',
    'newer:copy:lib',
    'locales',
    'ejs',
  ]);

  grunt.registerTask('check-entry-points', function () {
    const done = this.async();
    checkEntryPoints(config.webpack.build, {verbose: true}).then(stats =>
      done()
    );
  });

  grunt.registerTask('lint-entry-points', function () {
    const done = this.async();
    checkEntryPoints(config.webpack.build).then(stats => {
      console.log(
        [
          chalk.green(`[${stats.passed} passed]`),
          stats.silenced && chalk.yellow(`[${stats.silenced} silenced]`),
          stats.failed && chalk.red(`[${stats.failed} failed]`),
        ]
          .filter(f => f)
          .join(' ')
      );
      if (stats.failed > 0) {
        grunt.warn(
          `${stats.failed} entry points do not conform to naming conventions.\n` +
            `Run grunt check-entry-points for details.\n`
        );
      }
      done();
    });
  });

  grunt.registerTask('compile-firebase-rules', function () {
    if (process.env.RACK_ENV === 'production') {
      throw new Error(
        'Cannot compile firebase security rules on production.\n' +
          'Instead, upload security rules from the apps package which was downloaded from s3.'
      );
    }
    child_process.execSync('mkdir -p ./build/package/firebase');
    child_process.execSync(
      'yarn run firebase-bolt < ./firebase/rules.bolt > ./build/package/firebase/rules.json'
    );
  });

  grunt.registerTask('postbuild', [
    'newer:copy:static',
    'newer:sass',
    'compile-firebase-rules',
  ]);

  grunt.registerTask('build', [
    'prebuild',
    // For any minifiable libs, generate minified sources if they do not already
    // exist in our repo. Skip minification in development environment.
    envConstants.DEV ? 'noop' : 'uglify:lib',
    envConstants.DEV ? 'webpack:build' : 'webpack:uglify',
    'webpack:buildOffline',
    'notify:js-build',
    'postbuild',
    envConstants.DEV ? 'noop' : 'newer:copy:unhash',
  ]);

  // Builds the Service Worker used for the Code.org offline experience.
  grunt.registerTask('buildOffline', ['webpack:buildOffline']);

  grunt.registerTask('rebuild', ['clean', 'build']);

  grunt.registerTask('dev', [
    'prebuild',
    'newer:sass',
    'concurrent:watch',
    'postbuild',
  ]);

  grunt.registerTask('default', ['rebuild', 'test']);
};

// Exported for matching use in `run-tests-in-parallel.sh`
module.exports.MEM_PER_KARMA_PROCESS_MB = MEM_PER_KARMA_PROCESS_MB;
