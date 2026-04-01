const request = require('supertest');
const express = require('express');
const authRouter = require('./auth');

const app = express();
app.use(express.json());
app.use('/api/auth', authRouter);

describe('Auth Routes', () => {

  test('POST /api/auth/register - success', async () => {
    const res = await request(app)
      .post('/api/auth/register')
      .send({
        name: 'Jest Test User',
        email: `jest_${Date.now()}@test.com`,
        password: 'testpass123',
        role: 'student'
      });
    expect(res.statusCode).toBe(200);
    expect(res.body).toHaveProperty('token');
    expect(res.body.user).toHaveProperty('id');
    expect(res.body.user.role).toBe('student');
  });

  test('POST /api/auth/register - duplicate email returns 400', async () => {
    const email = `dup_${Date.now()}@test.com`;
    await request(app)
      .post('/api/auth/register')
      .send({ name: 'User1', email, password: 'pass123', role: 'student' });
    const res = await request(app)
      .post('/api/auth/register')
      .send({ name: 'User2', email, password: 'pass456', role: 'student' });
    expect(res.statusCode).toBe(400);
    expect(res.body).toHaveProperty('error');
  });

  test('POST /api/auth/register - missing fields returns 500', async () => {
    const res = await request(app)
      .post('/api/auth/register')
      .send({ name: 'No Email' });
    expect(res.statusCode).toBeGreaterThanOrEqual(400);
  });

  test('POST /api/auth/login - success', async () => {
    const email = `login_${Date.now()}@test.com`;
    await request(app)
      .post('/api/auth/register')
      .send({ name: 'Login User', email, password: 'mypassword', role: 'student' });
    const res = await request(app)
      .post('/api/auth/login')
      .send({ email, password: 'mypassword' });
    expect(res.statusCode).toBe(200);
    expect(res.body).toHaveProperty('token');
    expect(res.body.user).toHaveProperty('email', email);
  });

  test('POST /api/auth/login - wrong password returns 401', async () => {
    const email = `wrongpass_${Date.now()}@test.com`;
    await request(app)
      .post('/api/auth/register')
      .send({ name: 'Wrong Pass', email, password: 'correctpass', role: 'student' });
    const res = await request(app)
      .post('/api/auth/login')
      .send({ email, password: 'wrongpass' });
    expect(res.statusCode).toBe(401);
  });

  test('POST /api/auth/login - unknown email returns 401', async () => {
    const res = await request(app)
      .post('/api/auth/login')
      .send({ email: 'nobody@nowhere.com', password: 'pass' });
    expect(res.statusCode).toBe(401);
  });

});
