// Space Invader - Phaser 3 / 네온 레트로 / 스테이지형
// 조작: 키보드 좌우(←→/AD) + 모바일 하단 좌우 버튼. 발사는 자동.

const W = 480, H = 720;

let AC = null;
function beep(freq = 440, dur = 0.08, type = 'square', vol = 0.05) {
  try {
    if (!AC) AC = new (window.AudioContext || window.webkitAudioContext)();
    if (AC.state === 'suspended') AC.resume();
    const o = AC.createOscillator(), g = AC.createGain();
    o.type = type; o.frequency.value = freq;
    g.gain.setValueAtTime(vol, AC.currentTime);
    g.gain.exponentialRampToValueAtTime(0.0001, AC.currentTime + dur);
    o.connect(g); g.connect(AC.destination);
    o.start(); o.stop(AC.currentTime + dur);
  } catch (e) { /* 오디오 무시 */ }
}

class MainScene extends Phaser.Scene {
  constructor() { super('main'); }

  create() {
    this.score = 0; this.wave = 0; this.lives = 3;
    this.gameOver = false; this.invincibleUntil = 0;
    this.enemyDir = 1; this.enemySpeed = 40;
    this.boss = null;

    this.makeTextures();
    this.add.rectangle(W/2, H/2, W, H, 0x050510);

    // 별 배경
    this.stars = [];
    for (let i = 0; i < 90; i++) {
      const s = this.add.circle(Phaser.Math.Between(0, W), Phaser.Math.Between(0, H), Phaser.Math.FloatBetween(0.5, 1.8), 0x8888ff, Phaser.Math.FloatBetween(0.3, 1));
      s.speed = Phaser.Math.FloatBetween(20, 90);
      this.stars.push(s);
    }

    // HUD
    this.scoreText = this.add.text(12, 10, 'SCORE 0', { fontSize: '18px', color: '#00ffff', fontStyle: 'bold' });
    this.waveText = this.add.text(W - 12, 10, 'WAVE 1', { fontSize: '18px', color: '#ff4dff', fontStyle: 'bold' }).setOrigin(1, 0);
    this.livesText = this.add.text(12, 34, '♥♥♥', { fontSize: '18px', color: '#ff5577' });

    // 플레이어
    this.player = this.physics.add.sprite(W / 2, H - 90, 'player');
    this.player.setCollideWorldBounds(true);
    this.playerSpeed = 360;

    // 총알 그룹
    this.pBullets = this.physics.add.group({ defaultKey: 'b1', maxSize: 40 });
    this.eBullets = this.physics.add.group({ defaultKey: 'b2', maxSize: 80 });
    this.enemies = this.physics.add.group();

    // 보스 HP 바
    this.bossBarBg = this.add.rectangle(W/2, 62, 300, 10, 0x330011).setVisible(false);
    this.bossBar = this.add.rectangle(W/2, 62, 300, 10, 0xff2255).setVisible(false);

    // 중앙 메시지
    this.msgText = this.add.text(W/2, H/2, '', { fontSize: '34px', color: '#ffffff', fontStyle: 'bold', align: 'center' }).setOrigin(0.5).setDepth(10);

    // 충돌
    this.physics.add.overlap(this.pBullets, this.enemies, this.hitEnemy, null, this);
    this.physics.add.overlap(this.eBullets, this.player, this.hitPlayer, null, this);
    this.physics.add.overlap(this.enemies, this.player, (p, e) => this.hitPlayer(p, null, e), null, this);

    this.cursors = this.input.keyboard.createCursorKeys();
    this.keyA = this.input.keyboard.addKey('A');
    this.keyD = this.input.keyboard.addKey('D');

    // 자동 발사
    this.time.addEvent({ delay: 220, loop: true, callback: () => {
      if (!this.gameOver && this.player.active) this.firePlayer();
    }});

    // 적 발사 타이머
    this.time.addEvent({ delay: 700, loop: true, callback: () => {
      if (!this.gameOver) this.enemyFire();
    }});

    this.nextWave();
  }

  makeTextures() {
    if (this.textures.exists('player')) return;
    const g = this.make.graphics({ add: false });

    // 플레이어: 네온 시안 삼각기
    g.clear(); g.fillStyle(0x00ffff, 1); g.lineStyle(2, 0xffffff, 1);
    g.beginPath(); g.moveTo(18, 0); g.lineTo(36, 28); g.lineTo(18, 21); g.lineTo(0, 28); g.closePath(); g.fillPath(); g.strokePath();
    g.generateTexture('player', 36, 28);

    // 적 소형: 마젠타
    g.clear(); g.fillStyle(0xff4dff, 1); g.lineStyle(2, 0xffffff, 0.9);
    g.fillCircle(16, 14, 11); g.strokeCircle(16, 14, 11);
    g.fillStyle(0x050510, 1); g.fillCircle(11, 12, 3); g.fillCircle(21, 12, 3);
    g.generateTexture('e1', 32, 26);

    // 적 중형: 오렌지
    g.clear(); g.fillStyle(0xffaa00, 1); g.lineStyle(2, 0xffffff, 0.9);
    g.fillRoundedRect(0, 4, 40, 20, 6); g.strokeRoundedRect(0, 4, 40, 20, 6);
    g.fillStyle(0xff2222, 1); g.fillCircle(13, 14, 4); g.fillCircle(27, 14, 4);
    g.generateTexture('e2', 40, 28);

    // 보스
    g.clear(); g.fillStyle(0xff2255, 1); g.lineStyle(3, 0xffffff, 1);
    g.fillRoundedRect(0, 0, 130, 56, 10); g.strokeRoundedRect(0, 0, 130, 56, 10);
    g.fillStyle(0x550011, 1); g.fillCircle(35, 28, 10); g.fillCircle(65, 28, 10); g.fillCircle(95, 28, 10);
    g.lineStyle(2, 0xffff00, 1); g.strokeCircle(35, 28, 10); g.strokeCircle(65, 28, 10); g.strokeCircle(95, 28, 10);
    g.generateTexture('boss', 130, 56);

    // 총알
    g.clear(); g.fillStyle(0x00ffff, 1); g.fillRoundedRect(0, 0, 5, 16, 2);
    g.generateTexture('b1', 5, 16);
    g.clear(); g.fillStyle(0xff4488, 1); g.fillRoundedRect(0, 0, 6, 14, 2);
    g.generateTexture('b2', 6, 14);
    g.destroy();
  }

  nextWave() {
    this.wave++;
    this.waveText.setText('WAVE ' + this.wave);
    this.enemyDir = 1;
    this.showMsg('WAVE ' + this.wave + (this.wave % 3 === 0 ? '\nBOSS!' : ''), 1400);

    if (this.wave % 3 === 0) this.spawnBoss();
    else this.spawnFormation();

    beep(520, 0.15, 'square', 0.06);
  }

  spawnFormation() {
    const cols = 6;
    const rows = 3 + Math.min(2, Math.floor(this.wave / 2)); // 3~5줄
    const hpBonus = Math.floor(this.wave / 3);
    this.enemySpeed = 34 + this.wave * 7;
    const sx = 52, sy = 110, dx = 64, dy = 52;

    for (let r = 0; r < rows; r++) {
      for (let c = 0; c < cols; c++) {
        const mid = r >= rows - 1; // 아래줄 = 중형
        const e = this.enemies.create(sx + c * dx, sy + r * dy, mid ? 'e2' : 'e1');
        e.setData('hp', (mid ? 2 : 1) + (r === 0 && hpBonus > 0 ? 1 : 0));
        e.setData('score', mid ? 30 : 20);
        e.setData('boss', false);
        e.setVelocity(0, 0);
      }
    }
    this.boss = null;
    this.bossBarBg.setVisible(false); this.bossBar.setVisible(false);
  }

  spawnBoss() {
    const hp = 18 + this.wave * 6;
    const b = this.enemies.create(W / 2, 150, 'boss');
    b.setData('hp', hp); b.setData('maxHp', hp);
    b.setData('score', 500); b.setData('boss', true);
    b.setData('t', 0);
    this.boss = b; this.enemySpeed = 60;
    this.bossBarBg.setVisible(true); this.bossBar.setVisible(true);
  }

  firePlayer() {
    const b = this.pBullets.get(this.player.x, this.player.y - 24);
    if (!b) return;
    b.setActive(true).setVisible(true).setTexture('b1');
    b.body.setVelocity(0, -520);
    b.body.setSize(5, 16);
    beep(880, 0.05, 'square', 0.03);
  }

  enemyFire() {
    const alive = this.enemies.getChildren().filter(e => e.active);
    if (!alive.length) return;
    const pool = Math.min(alive.length, 1 + Math.floor(this.wave / 2));

    for (let i = 0; i < pool; i++) {
      const s = Phaser.Utils.Array.GetRandom(alive);
      if (!s || !s.active) continue;
      if (s.getData('boss')) { this.bossFire(s); continue; }
      const b = this.eBullets.get(s.x, s.y + 16);
      if (!b) continue;
      b.setActive(true).setVisible(true).setTexture('b2');
      const vx = Phaser.Math.Between(-40, 40);
      b.body.setVelocity(vx, 220 + this.wave * 12);
    }
  }

  bossFire(boss) {
    const n = 3 + Math.min(2, Math.floor(this.wave / 3));
    for (let i = 0; i < n; i++) {
      const b = this.eBullets.get(boss.x + (i - (n-1)/2) * 26, boss.y + 30);
      if (!b) continue;
      b.setActive(true).setVisible(true);
      b.body.setVelocity((i - (n-1)/2) * 70, 240 + this.wave * 8);
    }
    beep(160, 0.15, 'sawtooth', 0.05);
  }

  hitEnemy(bullet, enemy) {
    bullet.setActive(false).setVisible(false); bullet.body.stop();
    let hp = enemy.getData('hp') - 1;
    enemy.setData('hp', hp);
    this.explode(enemy.x, enemy.y, enemy.getData('boss') ? 0xff2255 : 0xffee00, enemy.getData('boss') ? 14 : 7);

    if (hp <= 0) {
      this.score += enemy.getData('score');
      this.scoreText.setText('SCORE ' + this.score);
      enemy.disableBody(true, true);
      beep(220, 0.12, 'square', 0.06);
      this.cameras.main.shake(80, 0.004);
      if (enemy.getData('boss')) { this.boss = null; this.bossBarBg.setVisible(false); this.bossBar.setVisible(false); }
      if (this.enemies.countActive(true) === 0) {
        this.time.delayedCall(900, () => { if (!this.gameOver) this.nextWave(); });
      }
    } else {
      beep(660, 0.05, 'square', 0.04);
      this.tweens.add({ targets: enemy, alpha: 0.4, duration: 60, yoyo: true });
      if (enemy.getData('boss')) this.updateBossBar(enemy);
    }
  }

  hitPlayer(player, bullet, directEnemy) {
    const now = this.time.now;
    if (this.gameOver || now < this.invincibleUntil) {
      if (bullet) { bullet.setActive(false).setVisible(false); bullet.body.stop(); }
      return;
    }
    if (bullet) { bullet.setActive(false).setVisible(false); bullet.body.stop(); }
    if (directEnemy) directEnemy.disableBody(true, true);

    this.lives--;
    this.livesText.setText('♥'.repeat(Math.max(0, this.lives)) || '—');
    this.explode(player.x, player.y, 0x00ffff, 12);
    this.cameras.main.shake(150, 0.01);
    beep(110, 0.3, 'sawtooth', 0.07);

    if (this.lives <= 0) {
      this.doGameOver();
    } else {
      this.invincibleUntil = now + 2000;
      this.tweens.add({ targets: player, alpha: 0.2, duration: 150, yoyo: true, repeat: 6, onComplete: () => player.setAlpha(1) });
    }
  }

  updateBossBar(b) {
    const r = Math.max(0, b.getData('hp') / b.getData('maxHp'));
    this.bossBar.displayWidth = 300 * r;
    this.bossBar.x = W/2 - (300 - 300*r)/2;
  }

  explode(x, y, color, n) {
    for (let i = 0; i < n; i++) {
      const p = this.add.circle(x, y, Phaser.Math.Between(2, 5), color);
      this.tweens.add({
        targets: p, x: x + Phaser.Math.Between(-50, 50), y: y + Phaser.Math.Between(-50, 50),
        alpha: 0, duration: Phaser.Math.Between(200, 450), onComplete: () => p.destroy()
      });
    }
  }

  showMsg(txt, ms) {
    this.msgText.setText(txt).setAlpha(1);
    this.tweens.killTweensOf(this.msgText);
    this.tweens.add({ targets: this.msgText, alpha: 0, delay: ms - 400, duration: 400 });
  }

  doGameOver() {
    this.gameOver = true;
    this.player.disableBody(true, true);
    this.showMsg('GAME OVER\nSCORE ' + this.score + '\n탭하여 재시작', 100000);
    this.msgText.setAlpha(1);
    this.input.once('pointerdown', () => this.scene.restart());
    // 모바일 버튼 탭도 재시작되게: 캔버스 탭 외 DOM 탭은 아래 once로 보완
    const retry = () => { window.removeEventListener('pointerdown', retry); if (this.scene.isActive('main')) this.scene.restart(); };
    window.addEventListener('pointerdown', retry, { once: true });
  }

  update(time, delta) {
    const dt = delta / 1000;
    for (const s of this.stars) { s.y += s.speed * dt; if (s.y > H) { s.y = 0; s.x = Phaser.Math.Between(0, W); } }

    if (!this.gameOver && this.player.active) {
      let dir = 0;
      if (this.cursors.left.isDown || this.keyA.isDown || window.__move.left) dir -= 1;
      if (this.cursors.right.isDown || this.keyD.isDown || window.__move.right) dir += 1;
      // 화면 터치 절반 분할도 지원 (버튼 없을 때 대비)
      if (this.input.activePointer.isDown && this.input.activePointer.y > H * 0.4) {
        dir = this.input.activePointer.x < W / 2 ? -1 : 1;
      }
      this.player.setVelocityX(dir * this.playerSpeed);
    }

    // 적 이동: 좌우 + 끝에서 하강
    const alive = this.enemies.getChildren().filter(e => e.active);
    if (alive.length) {
      if (this.boss && this.boss.active) {
        const t = this.time.now / 1000;
        this.boss.x = W/2 + Math.sin(t * 1.4) * (W/2 - 90);
        this.updateBossBar(this.boss);
      } else {
        let minX = 1e9, maxX = -1e9;
        for (const e of alive) { minX = Math.min(minX, e.x); maxX = Math.max(maxX, e.x); }
        if ((this.enemyDir > 0 && maxX > W - 24) || (this.enemyDir < 0 && minX < 24)) {
          this.enemyDir *= -1;
          for (const e of alive) e.y += 18;
        }
        for (const e of alive) e.x += this.enemyDir * this.enemySpeed * dt;
        // 적이 너무 내려오면 라이프 감소
        for (const e of alive) {
          if (e.y > this.player.y - 30 && e.active) { this.hitPlayer(this.player, null, e); break; }
        }
      }
    }

    // 화면 밖 총알 정리
    for (const b of [...this.pBullets.getChildren(), ...this.eBullets.getChildren()]) {
      if (b.active && (b.y < -30 || b.y > H + 30)) { b.setActive(false).setVisible(false); b.body.stop(); }
    }
  }
}

new Phaser.Game({
  type: Phaser.AUTO,
  parent: 'game',
  width: W, height: H,
  backgroundColor: '#050510',
  physics: { default: 'arcade', arcade: { debug: false } },
  scale: { mode: Phaser.Scale.FIT, autoCenter: Phaser.Scale.CENTER_BOTH },
  scene: [MainScene]
});
